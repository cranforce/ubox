/**
 * Visualforce controller for the "User Permission Report" PDF.
 *
 * Reuses UserManagementController.getUserEffectivePermissions (profile +
 * permission sets + permission set groups, with per-source attribution) and
 * getAllUserFieldPermissions (full FLS), then adds focused queries for the
 * pieces that aggregation doesn't cover (public groups, permission set /
 * package licenses, role). The Map/List data returned by those methods is
 * adapted into strongly-typed wrappers so the VF markup can iterate clean
 * lists instead of nested Map<String, Object> structures.
 *
 * Reached at /apex/ubox__UserPermissionsPdf?id=<userId>.
 */
public with sharing class UserPermissionsPdfController {

    public Boolean hasUser { get; private set; }
    public String generatedDate { get; private set; }

    public UserHeader header { get; private set; }
    public List<SourceRow> sources { get; private set; }
    public List<String> publicGroups { get; private set; }
    public List<String> permSetLicenses { get; private set; }
    public List<String> packageLicenses { get; private set; }
    public List<PermRow> userPermissions { get; private set; }
    public List<ObjectRow> objectPermissions { get; private set; }
    public List<TabRow> tabSettings { get; private set; }
    public List<AccessRow> appAccesses { get; private set; }
    public List<AccessRow> customPermissions { get; private set; }
    public List<FlsObject> fieldSecurity { get; private set; }

    // sourceId (e.g. 'ps:0PS...') -> user-facing label, for grant attribution.
    private Map<String, String> sourceLabelById = new Map<String, String>();

    public UserPermissionsPdfController() {
        generatedDate = System.now().format('MMMM d, yyyy \'at\' h:mm a');
        hasUser = false;
        sources = new List<SourceRow>();
        publicGroups = new List<String>();
        permSetLicenses = new List<String>();
        packageLicenses = new List<String>();
        userPermissions = new List<PermRow>();
        objectPermissions = new List<ObjectRow>();
        tabSettings = new List<TabRow>();
        appAccesses = new List<AccessRow>();
        customPermissions = new List<AccessRow>();
        fieldSecurity = new List<FlsObject>();

        String idParam = ApexPages.currentPage() != null
            ? ApexPages.currentPage().getParameters().get('id')
            : null;
        if (String.isBlank(idParam)) {
            return;
        }
        Id userId;
        try {
            userId = (Id) idParam;
        } catch (Exception e) {
            return;
        }
        if (userId.getSObjectType() != User.SObjectType) {
            return;
        }
        build(userId);
    }

    private void build(Id userId) {
        List<User> users = [
            SELECT Id, Name, Username, IsActive, Profile.Name,
                   Profile.UserLicense.Name, UserRole.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (users.isEmpty()) {
            return;
        }
        hasUser = true;
        User u = users[0];

        header = new UserHeader();
        header.name = u.Name;
        header.username = u.Username;
        header.status = u.IsActive ? 'Active' : 'Inactive';
        header.profileName = u.Profile != null ? u.Profile.Name : '—';
        header.licenseName = (u.Profile != null && u.Profile.UserLicense != null)
            ? u.Profile.UserLicense.Name : '—';
        header.roleName = u.UserRole != null ? u.UserRole.Name : '—';

        Map<String, Object> eff = UserManagementController.getUserEffectivePermissions(userId);

        for (Object o : (List<Object>) eff.get('sources')) {
            Map<String, Object> s = (Map<String, Object>) o;
            String sid = (String) s.get('sourceId');
            sourceLabelById.put(sid, (String) s.get('label'));
            SourceRow row = new SourceRow();
            row.label = (String) s.get('label');
            row.type = (String) s.get('type');
            sources.add(row);
        }

        buildUserPermissions(eff);
        buildObjectPermissions(eff);
        buildTabSettings(eff);
        buildAccessLists(eff);
        buildFieldSecurity(userId);
        buildAssignments(userId);
    }

    private void buildUserPermissions(Map<String, Object> eff) {
        for (Object o : (List<Object>) eff.get('userPermissions')) {
            Map<String, Object> m = (Map<String, Object>) o;
            PermRow row = new PermRow();
            row.label = (String) m.get('label');
            row.apiName = (String) m.get('apiName');
            row.sources = joinSources((List<Object>) m.get('sources'));
            userPermissions.add(row);
        }
    }

    private void buildObjectPermissions(Map<String, Object> eff) {
        for (Object o : (List<Object>) eff.get('objectPermissions')) {
            Map<String, Object> m = (Map<String, Object>) o;
            ObjectRow row = new ObjectRow();
            row.label = (String) m.get('label');
            row.apiName = (String) m.get('apiName');
            row.read = mark(m.get('read'));
            row.create = mark(m.get('create'));
            row.edit = mark(m.get('edit'));
            row.del = mark(m.get('delete'));
            row.viewAll = mark(m.get('viewAll'));
            row.modifyAll = mark(m.get('modifyAll'));
            Set<String> srcIds = new Set<String>();
            for (Object gObj : (List<Object>) m.get('grants')) {
                Map<String, Object> g = (Map<String, Object>) gObj;
                srcIds.add((String) g.get('sourceId'));
            }
            row.sources = joinSourceIds(srcIds);
            objectPermissions.add(row);
        }
    }

    private void buildTabSettings(Map<String, Object> eff) {
        for (Object o : (List<Object>) eff.get('tabSettings')) {
            Map<String, Object> m = (Map<String, Object>) o;
            TabRow row = new TabRow();
            row.label = (String) m.get('label');
            row.apiName = (String) m.get('apiName');
            Set<String> visibilities = new Set<String>();
            Set<String> srcIds = new Set<String>();
            for (Object gObj : (List<Object>) m.get('grants')) {
                Map<String, Object> g = (Map<String, Object>) gObj;
                if (g.get('visibility') != null) visibilities.add((String) g.get('visibility'));
                srcIds.add((String) g.get('sourceId'));
            }
            List<String> visList = new List<String>(visibilities);
            visList.sort();
            row.visibility = String.join(visList, ', ');
            row.sources = joinSourceIds(srcIds);
            tabSettings.add(row);
        }
    }

    private void buildAccessLists(Map<String, Object> eff) {
        for (Object o : (List<Object>) eff.get('appAccesses')) {
            Map<String, Object> m = (Map<String, Object>) o;
            AccessRow row = new AccessRow();
            row.label = (String) m.get('label');
            row.apiName = qualifiedName((String) m.get('namespacePrefix'), (String) m.get('name'));
            row.sources = joinSources((List<Object>) m.get('sources'));
            appAccesses.add(row);
        }
        for (Object o : (List<Object>) eff.get('customPermissions')) {
            Map<String, Object> m = (Map<String, Object>) o;
            AccessRow row = new AccessRow();
            row.label = (String) m.get('label');
            row.apiName = qualifiedName((String) m.get('namespacePrefix'), (String) m.get('developerName'));
            row.sources = joinSources((List<Object>) m.get('sources'));
            customPermissions.add(row);
        }
    }

    private void buildFieldSecurity(Id userId) {
        Map<String, Object> flsData = UserManagementController.getAllUserFieldPermissions(userId);
        for (Object oObj : (List<Object>) flsData.get('objects')) {
            Map<String, Object> om = (Map<String, Object>) oObj;
            FlsObject fo = new FlsObject();
            fo.label = (String) om.get('label');
            fo.apiName = (String) om.get('apiName');
            fo.fields = new List<FlsField>();
            for (Object fObj : (List<Object>) om.get('fields')) {
                Map<String, Object> fm = (Map<String, Object>) fObj;
                FlsField ff = new FlsField();
                ff.label = (String) fm.get('label');
                ff.field = (String) fm.get('field');
                ff.read = mark(fm.get('read'));
                ff.edit = mark(fm.get('edit'));
                ff.sources = joinSources((List<Object>) fm.get('sources'));
                fo.fields.add(ff);
            }
            fieldSecurity.add(fo);
        }
    }

    private void buildAssignments(Id userId) {
        for (GroupMember gm : [
            SELECT Group.Name
            FROM GroupMember
            WHERE UserOrGroupId = :userId AND Group.Type = 'Regular'
            ORDER BY Group.Name
        ]) {
            if (gm.Group != null && gm.Group.Name != null) {
                publicGroups.add(gm.Group.Name);
            }
        }
        for (PermissionSetLicenseAssign psl : [
            SELECT PermissionSetLicense.MasterLabel
            FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :userId
            ORDER BY PermissionSetLicense.MasterLabel
        ]) {
            if (psl.PermissionSetLicense != null) {
                permSetLicenses.add(psl.PermissionSetLicense.MasterLabel);
            }
        }
        List<String> pkgs = new List<String>();
        for (UserPackageLicense upl : [
            SELECT PackageLicense.NamespacePrefix
            FROM UserPackageLicense
            WHERE UserId = :userId
        ]) {
            String ns = upl.PackageLicense != null ? upl.PackageLicense.NamespacePrefix : null;
            pkgs.add(String.isBlank(ns) ? '(unnamed package)' : ns);
        }
        pkgs.sort();
        packageLicenses = pkgs;
    }

    // ---- helpers ---------------------------------------------------------

    private String mark(Object val) {
        return val == true ? 'Yes' : '';
    }

    private String qualifiedName(String ns, String name) {
        return String.isBlank(ns) ? name : ns + '.' + name;
    }

    private String joinSources(List<Object> sourceIds) {
        Set<String> sids = new Set<String>();
        if (sourceIds != null) {
            for (Object o : sourceIds) sids.add((String) o);
        }
        return joinSourceIds(sids);
    }

    private String joinSourceIds(Set<String> sids) {
        Set<String> labels = new Set<String>();
        for (String sid : sids) {
            labels.add(sourceLabelById.containsKey(sid) ? sourceLabelById.get(sid) : sid);
        }
        List<String> sorted = new List<String>(labels);
        sorted.sort();
        return String.join(sorted, ', ');
    }

    // ---- rendered-condition getters for the VF page ----------------------

    public Boolean getHasSources() { return !sources.isEmpty(); }
    public Boolean getHasPublicGroups() { return !publicGroups.isEmpty(); }
    public Boolean getHasPermSetLicenses() { return !permSetLicenses.isEmpty(); }
    public Boolean getHasPackageLicenses() { return !packageLicenses.isEmpty(); }
    public Boolean getHasUserPermissions() { return !userPermissions.isEmpty(); }
    public Boolean getHasObjectPermissions() { return !objectPermissions.isEmpty(); }
    public Boolean getHasTabSettings() { return !tabSettings.isEmpty(); }
    public Boolean getHasAppAccesses() { return !appAccesses.isEmpty(); }
    public Boolean getHasCustomPermissions() { return !customPermissions.isEmpty(); }
    public Boolean getHasFieldSecurity() { return !fieldSecurity.isEmpty(); }

    // ---- wrapper types ---------------------------------------------------

    public class UserHeader {
        public String name { get; set; }
        public String username { get; set; }
        public String status { get; set; }
        public String profileName { get; set; }
        public String roleName { get; set; }
        public String licenseName { get; set; }
    }

    public class SourceRow {
        public String label { get; set; }
        public String type { get; set; }
    }

    public class PermRow {
        public String label { get; set; }
        public String apiName { get; set; }
        public String sources { get; set; }
    }

    public class ObjectRow {
        public String label { get; set; }
        public String apiName { get; set; }
        public String read { get; set; }
        public String create { get; set; }
        public String edit { get; set; }
        public String del { get; set; }
        public String viewAll { get; set; }
        public String modifyAll { get; set; }
        public String sources { get; set; }
    }

    public class TabRow {
        public String label { get; set; }
        public String apiName { get; set; }
        public String visibility { get; set; }
        public String sources { get; set; }
    }

    public class AccessRow {
        public String label { get; set; }
        public String apiName { get; set; }
        public String sources { get; set; }
    }

    public class FlsObject {
        public String label { get; set; }
        public String apiName { get; set; }
        public List<FlsField> fields { get; set; }
    }

    public class FlsField {
        public String label { get; set; }
        public String field { get; set; }
        public String read { get; set; }
        public String edit { get; set; }
        public String sources { get; set; }
    }
}
