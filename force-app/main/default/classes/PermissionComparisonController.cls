/**
 * Compares the permissions of two users and returns only the differences.
 *
 * Reuses UserManagementController.getUserEffectivePermissions (system / object /
 * tab / app / custom permissions, profile already folded in) and
 * getAllUserFieldPermissions (full FLS), then adds direct queries for the named
 * "mechanisms" (profile, permission sets, permission set groups, public groups,
 * licenses). Diffing happens server-side so the payload carries only the deltas.
 *
 * The result is a plain Map/List structure (matching the other uBox controllers)
 * so the LWC can consume the JSON directly. For each category: onlyA / onlyB, and
 * where an item exists for both users but its settings diverge, a `different`
 * entry holding both sides.
 */
public with sharing class PermissionComparisonController {

    private static final List<String> CRUD_KEYS = new List<String>{
        'read', 'create', 'edit', 'delete', 'viewAll', 'modifyAll'
    };

    @AuraEnabled
    public static Map<String, Object> getComparison(Id userAId, Id userBId) {
        if (userAId == null || userBId == null) {
            throw badRequest('Two users are required for a comparison.');
        }
        if (userAId.getSObjectType() != User.SObjectType ||
            userBId.getSObjectType() != User.SObjectType) {
            throw badRequest('Both records must be users.');
        }
        if (userAId == userBId) {
            throw badRequest('Select two different users to compare.');
        }

        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Name, Profile.Name FROM User WHERE Id IN (:userAId, :userBId)
        ]);
        if (!usersById.containsKey(userAId) || !usersById.containsKey(userBId)) {
            throw badRequest('One or both users could not be found.');
        }
        User uA = usersById.get(userAId);
        User uB = usersById.get(userBId);

        Map<String, Object> effA = UserManagementController.getUserEffectivePermissions(userAId);
        Map<String, Object> effB = UserManagementController.getUserEffectivePermissions(userBId);
        Map<String, Object> flsA = UserManagementController.getAllUserFieldPermissions(userAId);
        Map<String, Object> flsB = UserManagementController.getAllUserFieldPermissions(userBId);

        Map<String, Object> result = new Map<String, Object>{
            'userA' => new Map<String, Object>{ 'id' => uA.Id, 'name' => uA.Name },
            'userB' => new Map<String, Object>{ 'id' => uB.Id, 'name' => uB.Name },
            'mechanisms' => diffMechanisms(uA, uB),
            'systemPermissions' => diffSystemPermissions(effA, effB),
            'objectPermissions' => diffObjectPermissions(effA, effB),
            'fieldSecurity' => diffFieldSecurity(flsA, flsB),
            'tabSettings' => diffTabSettings(effA, effB),
            'appAccesses' => diffPresence(effA, effB, 'appAccesses', 'name'),
            'customPermissions' => diffPresence(effA, effB, 'customPermissions', 'developerName')
        };
        result.put('hasDifferences', computeHasDifferences(result));
        return result;
    }

    // ---- mechanisms -------------------------------------------------------

    private static Map<String, Object> diffMechanisms(User uA, User uB) {
        Map<String, Set<String>> a = mechanismSets(uA.Id);
        Map<String, Set<String>> b = mechanismSets(uB.Id);

        String profA = uA.Profile != null ? uA.Profile.Name : null;
        String profB = uB.Profile != null ? uB.Profile.Name : null;

        return new Map<String, Object>{
            'profile' => new Map<String, Object>{
                'a' => profA, 'b' => profB, 'differs' => profA != profB
            },
            'permissionSets' => diffSet(a.get('ps'), b.get('ps')),
            'permissionSetGroups' => diffSet(a.get('psg'), b.get('psg')),
            'publicGroups' => diffSet(a.get('groups'), b.get('groups')),
            'permSetLicenses' => diffSet(a.get('psl'), b.get('psl')),
            'packageLicenses' => diffSet(a.get('pkg'), b.get('pkg'))
        };
    }

    private static Map<String, Set<String>> mechanismSets(Id userId) {
        Set<String> ps = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Label FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSet.IsOwnedByProfile = false
              AND PermissionSetGroupId = null
        ]) {
            ps.add(psa.PermissionSet.Label);
        }
        Set<String> psg = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetGroup.MasterLabel FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSetGroupId != null
        ]) {
            if (psa.PermissionSetGroup != null) psg.add(psa.PermissionSetGroup.MasterLabel);
        }
        Set<String> groups = new Set<String>();
        for (GroupMember gm : [
            SELECT Group.Name FROM GroupMember
            WHERE UserOrGroupId = :userId AND Group.Type = 'Regular'
        ]) {
            if (gm.Group != null && gm.Group.Name != null) groups.add(gm.Group.Name);
        }
        Set<String> psl = new Set<String>();
        for (PermissionSetLicenseAssign a : [
            SELECT PermissionSetLicense.MasterLabel FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :userId
        ]) {
            if (a.PermissionSetLicense != null) psl.add(a.PermissionSetLicense.MasterLabel);
        }
        Set<String> pkg = new Set<String>();
        for (UserPackageLicense a : [
            SELECT PackageLicense.NamespacePrefix FROM UserPackageLicense
            WHERE UserId = :userId
        ]) {
            String ns = a.PackageLicense != null ? a.PackageLicense.NamespacePrefix : null;
            pkg.add(String.isBlank(ns) ? '(unnamed package)' : ns);
        }
        return new Map<String, Set<String>>{
            'ps' => ps, 'psg' => psg, 'groups' => groups, 'psl' => psl, 'pkg' => pkg
        };
    }

    // ---- effective permission diffs --------------------------------------

    private static Map<String, Object> diffSystemPermissions(
            Map<String, Object> effA, Map<String, Object> effB) {
        Map<String, Map<String, Object>> a = indexBy(effA.get('userPermissions'), 'apiName');
        Map<String, Map<String, Object>> b = indexBy(effB.get('userPermissions'), 'apiName');
        List<Object> onlyA = new List<Object>();
        List<Object> onlyB = new List<Object>();
        for (String key : sortedKeys(a.keySet())) {
            if (!b.containsKey(key)) onlyA.add(labelEntry(a.get(key)));
        }
        for (String key : sortedKeys(b.keySet())) {
            if (!a.containsKey(key)) onlyB.add(labelEntry(b.get(key)));
        }
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB };
    }

    private static Map<String, Object> diffObjectPermissions(
            Map<String, Object> effA, Map<String, Object> effB) {
        Map<String, Map<String, Object>> a = indexBy(effA.get('objectPermissions'), 'apiName');
        Map<String, Map<String, Object>> b = indexBy(effB.get('objectPermissions'), 'apiName');
        List<Object> onlyA = new List<Object>();
        List<Object> onlyB = new List<Object>();
        List<Object> different = new List<Object>();
        for (String key : sortedKeys(a.keySet())) {
            Map<String, Object> ao = a.get(key);
            if (!b.containsKey(key)) {
                onlyA.add(objectEntry(ao));
            } else if (crudDiffers(ao, b.get(key))) {
                different.add(new Map<String, Object>{
                    'apiName' => ao.get('apiName'),
                    'label' => ao.get('label'),
                    'a' => crudMap(ao),
                    'b' => crudMap(b.get(key))
                });
            }
        }
        for (String key : sortedKeys(b.keySet())) {
            if (!a.containsKey(key)) onlyB.add(objectEntry(b.get(key)));
        }
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB, 'different' => different };
    }

    private static Map<String, Object> diffFieldSecurity(
            Map<String, Object> flsA, Map<String, Object> flsB) {
        Map<String, Map<String, Object>> a = flattenFls(flsA);
        Map<String, Map<String, Object>> b = flattenFls(flsB);
        List<Object> onlyA = new List<Object>();
        List<Object> onlyB = new List<Object>();
        List<Object> different = new List<Object>();
        for (String key : sortedKeys(a.keySet())) {
            Map<String, Object> af = a.get(key);
            if (!b.containsKey(key)) {
                onlyA.add(flsEntry(af));
            } else {
                Map<String, Object> bf = b.get(key);
                if (af.get('read') != bf.get('read') || af.get('edit') != bf.get('edit')) {
                    different.add(new Map<String, Object>{
                        'object' => af.get('object'),
                        'objectLabel' => af.get('objectLabel'),
                        'field' => af.get('field'),
                        'label' => af.get('label'),
                        'a' => new Map<String, Object>{ 'read' => af.get('read'), 'edit' => af.get('edit') },
                        'b' => new Map<String, Object>{ 'read' => bf.get('read'), 'edit' => bf.get('edit') }
                    });
                }
            }
        }
        for (String key : sortedKeys(b.keySet())) {
            if (!a.containsKey(key)) onlyB.add(flsEntry(b.get(key)));
        }
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB, 'different' => different };
    }

    private static Map<String, Object> diffTabSettings(
            Map<String, Object> effA, Map<String, Object> effB) {
        Map<String, Map<String, Object>> a = indexBy(effA.get('tabSettings'), 'apiName');
        Map<String, Map<String, Object>> b = indexBy(effB.get('tabSettings'), 'apiName');
        List<Object> onlyA = new List<Object>();
        List<Object> onlyB = new List<Object>();
        List<Object> different = new List<Object>();
        for (String key : sortedKeys(a.keySet())) {
            Map<String, Object> at = a.get(key);
            String av = tabVisibility(at);
            if (!b.containsKey(key)) {
                onlyA.add(tabEntry(at, av));
            } else {
                String bv = tabVisibility(b.get(key));
                if (av != bv) {
                    different.add(new Map<String, Object>{
                        'apiName' => at.get('apiName'),
                        'label' => at.get('label'),
                        'a' => av,
                        'b' => bv
                    });
                }
            }
        }
        for (String key : sortedKeys(b.keySet())) {
            if (!a.containsKey(key)) onlyB.add(tabEntry(b.get(key), tabVisibility(b.get(key))));
        }
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB, 'different' => different };
    }

    // Presence-only diff for apps and custom permissions (keyed by namespace +
    // api name; label carried for display).
    private static Map<String, Object> diffPresence(
            Map<String, Object> effA, Map<String, Object> effB,
            String listKey, String nameKey) {
        Map<String, Map<String, Object>> a = keyByQualifiedName(effA.get(listKey), nameKey);
        Map<String, Map<String, Object>> b = keyByQualifiedName(effB.get(listKey), nameKey);
        List<Object> onlyA = new List<Object>();
        List<Object> onlyB = new List<Object>();
        for (String key : sortedKeys(a.keySet())) {
            if (!b.containsKey(key)) {
                onlyA.add(new Map<String, Object>{ 'label' => a.get(key).get('label'), 'apiName' => key });
            }
        }
        for (String key : sortedKeys(b.keySet())) {
            if (!a.containsKey(key)) {
                onlyB.add(new Map<String, Object>{ 'label' => b.get(key).get('label'), 'apiName' => key });
            }
        }
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB };
    }

    // ---- helpers ----------------------------------------------------------

    private static Map<String, Object> diffSet(Set<String> a, Set<String> b) {
        List<String> onlyA = new List<String>();
        List<String> onlyB = new List<String>();
        for (String v : a) {
            if (!b.contains(v)) onlyA.add(v);
        }
        for (String v : b) {
            if (!a.contains(v)) onlyB.add(v);
        }
        onlyA.sort();
        onlyB.sort();
        return new Map<String, Object>{ 'onlyA' => onlyA, 'onlyB' => onlyB };
    }

    private static Map<String, Map<String, Object>> indexBy(Object listObj, String keyField) {
        Map<String, Map<String, Object>> m = new Map<String, Map<String, Object>>();
        if (listObj == null) return m;
        for (Object o : (List<Object>) listObj) {
            Map<String, Object> mm = (Map<String, Object>) o;
            m.put((String) mm.get(keyField), mm);
        }
        return m;
    }

    private static Map<String, Map<String, Object>> keyByQualifiedName(Object listObj, String nameKey) {
        Map<String, Map<String, Object>> m = new Map<String, Map<String, Object>>();
        if (listObj == null) return m;
        for (Object o : (List<Object>) listObj) {
            Map<String, Object> mm = (Map<String, Object>) o;
            String ns = (String) mm.get('namespacePrefix');
            String name = (String) mm.get(nameKey);
            String key = String.isBlank(ns) ? name : ns + '.' + name;
            m.put(key, mm);
        }
        return m;
    }

    // Flattens the { objects: [ { apiName, label, fields: [...] } ] } FLS shape
    // into object||field -> entry for O(1) diffing.
    private static Map<String, Map<String, Object>> flattenFls(Map<String, Object> fls) {
        Map<String, Map<String, Object>> m = new Map<String, Map<String, Object>>();
        for (Object oObj : (List<Object>) fls.get('objects')) {
            Map<String, Object> om = (Map<String, Object>) oObj;
            String objApi = (String) om.get('apiName');
            String objLabel = (String) om.get('label');
            for (Object fObj : (List<Object>) om.get('fields')) {
                Map<String, Object> fm = (Map<String, Object>) fObj;
                String field = (String) fm.get('field');
                m.put(objApi + '||' + field, new Map<String, Object>{
                    'object' => objApi,
                    'objectLabel' => objLabel,
                    'field' => field,
                    'label' => fm.get('label'),
                    'read' => fm.get('read') == true,
                    'edit' => fm.get('edit') == true
                });
            }
        }
        return m;
    }

    private static Boolean crudDiffers(Map<String, Object> a, Map<String, Object> b) {
        for (String k : CRUD_KEYS) {
            if ((a.get(k) == true) != (b.get(k) == true)) return true;
        }
        return false;
    }

    private static Map<String, Object> crudMap(Map<String, Object> o) {
        Map<String, Object> m = new Map<String, Object>();
        for (String k : CRUD_KEYS) {
            m.put(k, o.get(k) == true);
        }
        return m;
    }

    private static Map<String, Object> objectEntry(Map<String, Object> o) {
        Map<String, Object> m = crudMap(o);
        m.put('apiName', o.get('apiName'));
        m.put('label', o.get('label'));
        return m;
    }

    private static Map<String, Object> labelEntry(Map<String, Object> o) {
        return new Map<String, Object>{ 'apiName' => o.get('apiName'), 'label' => o.get('label') };
    }

    private static Map<String, Object> flsEntry(Map<String, Object> f) {
        return new Map<String, Object>{
            'object' => f.get('object'),
            'objectLabel' => f.get('objectLabel'),
            'field' => f.get('field'),
            'label' => f.get('label'),
            'read' => f.get('read'),
            'edit' => f.get('edit')
        };
    }

    private static Map<String, Object> tabEntry(Map<String, Object> t, String visibility) {
        return new Map<String, Object>{
            'apiName' => t.get('apiName'),
            'label' => t.get('label'),
            'visibility' => visibility
        };
    }

    // Effective tab visibility for a user = the distinct grant visibilities,
    // sorted and joined. Comparing these strings surfaces visibility divergence
    // without needing to rank Salesforce's visibility values.
    private static String tabVisibility(Map<String, Object> tab) {
        Set<String> vis = new Set<String>();
        for (Object gObj : (List<Object>) tab.get('grants')) {
            Map<String, Object> g = (Map<String, Object>) gObj;
            if (g.get('visibility') != null) vis.add((String) g.get('visibility'));
        }
        List<String> visList = new List<String>(vis);
        visList.sort();
        return String.join(visList, ', ');
    }

    private static List<String> sortedKeys(Set<String> keys) {
        List<String> l = new List<String>(keys);
        l.sort();
        return l;
    }

    private static Boolean computeHasDifferences(Map<String, Object> result) {
        Map<String, Object> mech = (Map<String, Object>) result.get('mechanisms');
        Map<String, Object> profile = (Map<String, Object>) mech.get('profile');
        if (profile.get('differs') == true) return true;
        for (String k : new List<String>{
                'permissionSets', 'permissionSetGroups', 'publicGroups',
                'permSetLicenses', 'packageLicenses'}) {
            if (nonEmptyDiff((Map<String, Object>) mech.get(k))) return true;
        }
        for (String cat : new List<String>{
                'systemPermissions', 'objectPermissions', 'fieldSecurity',
                'tabSettings', 'appAccesses', 'customPermissions'}) {
            if (nonEmptyDiff((Map<String, Object>) result.get(cat))) return true;
        }
        return false;
    }

    private static Boolean nonEmptyDiff(Map<String, Object> diff) {
        if (diff == null) return false;
        for (String k : new List<String>{ 'onlyA', 'onlyB', 'different' }) {
            Object v = diff.get(k);
            if (v != null && !((List<Object>) v).isEmpty()) return true;
        }
        return false;
    }

    private static AuraHandledException badRequest(String msg) {
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        return ex;
    }
}
