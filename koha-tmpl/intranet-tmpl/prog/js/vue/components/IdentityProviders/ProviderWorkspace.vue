<template>
    <div v-if="!initialized">{{ $__("Loading...") }}</div>
    <div v-else>
        <!-- Page header -->
        <div class="d-flex justify-content-between align-items-center mb-3">
            <div>
                <h1 class="h2 mb-0">
                    {{ provider.description || provider.code }}
                </h1>
                <small class="text-muted">
                    <code>{{ provider.code }}</code>
                    <span
                        v-if="provider.protocol"
                        class="badge bg-light text-dark border ms-1"
                        >{{ provider.protocol }}</span
                    >
                </small>
            </div>
            <span v-if="provider.enabled" class="badge bg-success fs-6">{{
                $__("Active")
            }}</span>
            <span v-else class="badge bg-secondary fs-6">{{
                $__("Inactive")
            }}</span>
        </div>

        <!-- ─────────────────────────────────────────────────────────── -->
        <!-- Section 1: IdP Connection Settings                         -->
        <!-- ─────────────────────────────────────────────────────────── -->
        <div class="page-section">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h2>
                    <i class="fa fa-plug"></i>
                    {{ $__("1. IdP Connection Settings") }}
                </h2>
                <button
                    v-if="!editingSection1"
                    type="button"
                    class="btn btn-default"
                    @click="startEditSection1"
                >
                    <i class="fa fa-pencil"></i>
                    {{ $__("Edit") }}
                </button>
            </div>

            <!-- VIEW MODE -->
            <template v-if="!editingSection1">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label>{{ $__("Code") }}</label>
                            <span>{{ provider.code }}</span>
                        </li>
                        <li>
                            <label>{{ $__("Description") }}</label>
                            <span>{{
                                provider.description || $__("(none)")
                            }}</span>
                        </li>
                        <li>
                            <label>{{ $__("Type") }}</label>
                            <span>{{
                                provider.protocol || $__("(not set)")
                            }}</span>
                        </li>
                        <li>
                            <label>{{ $__("Icon URL") }}</label>
                            <span>{{
                                provider.icon_url || $__("(none)")
                            }}</span>
                        </li>
                        <li>
                            <label>{{ $__("Enabled") }}</label>
                            <span>
                                <span
                                    v-if="provider.enabled"
                                    class="badge bg-success"
                                    >{{ $__("Yes") }}</span
                                >
                                <span v-else class="badge bg-secondary">{{
                                    $__("No")
                                }}</span>
                            </span>
                        </li>
                    </ol>
                </fieldset>
                <div
                    v-if="provider.protocol && configFields.length"
                    class="card mt-3"
                >
                    <div class="card-header">
                        <strong>{{ $__("Type-specific fields") }}</strong>
                        ({{ provider.protocol }})
                    </div>
                    <div class="card-body">
                        <fieldset class="rows">
                            <ol>
                                <li
                                    v-for="field in configFields"
                                    :key="field.name"
                                >
                                    <label>{{ field.label }}</label>
                                    <span v-if="field.type === 'boolean'">
                                        <span
                                            v-if="configData[field.name]"
                                            class="badge bg-success"
                                            >{{ $__("Yes") }}</span
                                        >
                                        <span
                                            v-else
                                            class="badge bg-secondary"
                                            >{{ $__("No") }}</span
                                        >
                                    </span>
                                    <span v-else>{{
                                        configData[field.name] ||
                                        $__("(not set)")
                                    }}</span>
                                </li>
                            </ol>
                        </fieldset>
                    </div>
                </div>
            </template>

            <!-- EDIT MODE -->
            <template v-else>
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label class="required" for="idp-code">{{
                                $__("Code")
                            }}</label>
                            <input
                                id="idp-code"
                                type="text"
                                class="form-control"
                                v-model="providerEdit.code"
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="idp-description">{{
                                $__("Description")
                            }}</label>
                            <input
                                id="idp-description"
                                type="text"
                                class="form-control"
                                v-model="providerEdit.description"
                            />
                        </li>
                        <li>
                            <label class="required" for="idp-protocol">{{
                                $__("Type")
                            }}</label>
                            <select
                                id="idp-protocol"
                                class="form-select"
                                v-model="providerEdit.protocol"
                                @change="onProtocolChangeEdit"
                            >
                                <option value="">
                                    {{ $__("-- Select type --") }}
                                </option>
                                <option value="OAuth">OAuth</option>
                                <option value="OIDC">OIDC</option>
                                <option value="SAML2">
                                    SAML2 / Shibboleth
                                </option>
                                <option value="CAS">CAS</option>
                            </select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="idp-icon-url">{{
                                $__("Icon URL")
                            }}</label>
                            <input
                                id="idp-icon-url"
                                type="text"
                                class="form-control"
                                v-model="providerEdit.icon_url"
                            />
                        </li>
                        <li>
                            <label for="idp-enabled">{{
                                $__("Enabled")
                            }}</label>
                            <div class="form-check form-switch">
                                <input
                                    class="form-check-input"
                                    type="checkbox"
                                    id="idp-enabled"
                                    v-model="providerEdit.enabled"
                                    role="switch"
                                />
                            </div>
                        </li>
                    </ol>
                </fieldset>

                <!-- Type-specific config fields (edit mode) -->
                <div
                    v-if="providerEdit.protocol && configFieldsForEdit.length"
                    class="card mt-3"
                >
                    <div class="card-header">
                        <strong>{{ $__("Type-specific fields") }}</strong>
                        ({{ providerEdit.protocol }})
                    </div>
                    <div class="card-body">
                        <fieldset class="rows">
                            <ol>
                                <li
                                    v-for="field in configFieldsForEdit"
                                    :key="field.name"
                                >
                                    <label :for="'cfg-edit-' + field.name">
                                        {{ field.label }}
                                        <span
                                            v-if="field.required"
                                            class="required"
                                            >*</span
                                        >
                                    </label>
                                    <template v-if="field.type === 'text'">
                                        <input
                                            :id="'cfg-edit-' + field.name"
                                            type="text"
                                            class="form-control"
                                            v-model="configDataEdit[field.name]"
                                        />
                                        <span
                                            v-if="field.toolTip"
                                            class="text-muted ms-2"
                                            >{{ field.toolTip }}</span
                                        >
                                    </template>
                                    <template
                                        v-else-if="field.type === 'boolean'"
                                    >
                                        <div class="form-check form-switch">
                                            <input
                                                class="form-check-input"
                                                type="checkbox"
                                                :id="'cfg-edit-' + field.name"
                                                v-model="
                                                    configDataEdit[field.name]
                                                "
                                                role="switch"
                                            />
                                        </div>
                                        <span
                                            v-if="field.toolTip"
                                            class="text-muted ms-2"
                                            >{{ field.toolTip }}</span
                                        >
                                    </template>
                                </li>
                            </ol>
                        </fieldset>
                    </div>
                </div>

                <fieldset class="action">
                    <button
                        type="button"
                        class="btn btn-primary"
                        @click="saveSection1"
                        :disabled="savingSection1"
                    >
                        <i class="fa fa-save"></i>
                        {{ savingSection1 ? $__("Saving...") : $__("Save") }}
                    </button>
                    <a
                        class="cancel"
                        href="#"
                        @click.prevent="cancelSection1"
                        >{{ $__("Cancel") }}</a
                    >
                </fieldset>
            </template>
        </div>

        <!-- ─────────────────────────────────────────────────────────── -->
        <!-- Section 2: Network & Entry Settings                        -->
        <!-- ─────────────────────────────────────────────────────────── -->
        <div class="page-section">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h2>
                    <i class="fa fa-network-wired"></i>
                    {{ $__("2. Network & Entry Settings") }}
                </h2>
                <button
                    v-if="!editingSection2"
                    type="button"
                    class="btn btn-default"
                    @click="startEditSection2"
                >
                    <i class="fa fa-pencil"></i>
                    {{ $__("Edit") }}
                </button>
            </div>
            <p class="text-muted">
                {{
                    $__(
                        "Control which hostnames surface this provider on their login pages."
                    )
                }}
            </p>

            <div v-if="hostnamesLoading" class="text-muted">
                {{ $__("Loading...") }}
            </div>

            <!-- VIEW MODE: read-only list of linked hostnames -->
            <template v-else-if="!editingSection2">
                <ul class="list-group">
                    <li
                        v-for="row in hostnameRows.filter(r => r.is_linked)"
                        :key="row.hostname"
                        class="list-group-item d-flex justify-content-between align-items-center"
                    >
                        <code>{{ row.hostname }}</code>
                        <span class="d-flex gap-1 flex-shrink-0">
                            <span
                                v-if="row.is_enabled"
                                class="badge bg-success"
                                >{{ $__("Active") }}</span
                            >
                            <span v-else class="badge bg-warning text-dark">{{
                                $__("Inactive")
                            }}</span>
                            <span
                                v-if="row.force_sso_opac"
                                class="badge bg-primary"
                                :title="$__('Force SSO: OPAC')"
                                >{{ $__("SSO OPAC") }}</span
                            >
                            <span
                                v-if="row.force_sso_staff"
                                class="badge bg-primary"
                                :title="$__('Force SSO: staff')"
                                >{{ $__("SSO Staff") }}</span
                            >
                            <span
                                v-if="row.other_providers.length"
                                class="badge bg-info text-dark"
                                :title="row.other_providers.join(', ')"
                            >
                                +{{ row.other_providers.length }}
                            </span>
                        </span>
                    </li>
                    <li
                        v-if="
                            hostnameRows.filter(r => r.is_linked).length === 0
                        "
                        class="list-group-item text-muted"
                    >
                        {{ $__("No hostnames linked to this provider.") }}
                    </li>
                </ul>
            </template>

            <!-- EDIT MODE: full interactive split panel -->
            <template v-else>
                <div class="row g-0 border rounded">
                    <!-- Left: hostname list -->
                    <div class="col-md-3 border-end bg-light">
                        <div
                            class="list-group list-group-flush"
                            style="max-height: 360px; overflow-y: auto"
                        >
                            <button
                                v-for="row in hostnameRows"
                                :key="row.hostname"
                                type="button"
                                class="list-group-item list-group-item-action d-flex justify-content-between align-items-center py-2"
                                :class="{
                                    active:
                                        selectedHostname?.hostname ===
                                        row.hostname,
                                }"
                                @click="selectHostname(row)"
                            >
                                <span class="text-truncate me-2 small">{{
                                    row.hostname
                                }}</span>
                                <span class="d-flex gap-1 flex-shrink-0">
                                    <span
                                        v-if="row.is_linked && row.is_enabled"
                                        class="badge bg-success"
                                        >{{ $__("Active") }}</span
                                    >
                                    <span
                                        v-else-if="
                                            row.is_linked && !row.is_enabled
                                        "
                                        class="badge bg-warning text-dark"
                                        >{{ $__("Inactive") }}</span
                                    >
                                    <span
                                        v-if="row.other_providers.length"
                                        class="badge bg-info text-dark"
                                        :title="row.other_providers.join(', ')"
                                    >
                                        +{{ row.other_providers.length }}
                                    </span>
                                </span>
                            </button>
                            <div
                                v-if="hostnameRows.length === 0"
                                class="list-group-item text-muted small"
                            >
                                {{ $__("No hostnames configured.") }}
                            </div>
                        </div>
                        <div class="p-2 border-top">
                            <button
                                type="button"
                                class="btn btn-sm btn-default w-100"
                                @click="openAddHostnameDialog"
                            >
                                <i class="fa fa-plus"></i>
                                {{ $__("Add Hostname") }}
                            </button>
                        </div>
                    </div>

                    <!-- Right: hostname configuration -->
                    <div class="col-md-9 p-3">
                        <div
                            v-if="!selectedHostname"
                            class="d-flex align-items-center justify-content-center h-100 text-muted"
                            style="min-height: 200px"
                        >
                            {{
                                $__(
                                    "Select a hostname to configure its connection mode"
                                )
                            }}
                        </div>
                        <template v-else>
                            <h5>
                                {{ $__("Hostname Configuration") }}:
                                <code>{{ selectedHostname.hostname }}</code>
                            </h5>

                            <div
                                v-if="selectedHostname.other_providers.length"
                                class="alert alert-info py-2"
                            >
                                <i class="fa fa-info-circle"></i>
                                {{ $__("Also used by:") }}
                                <span
                                    v-for="name in selectedHostname.other_providers"
                                    :key="name"
                                    class="badge bg-info text-dark ms-1"
                                    >{{ name }}</span
                                >
                            </div>

                            <fieldset class="rows">
                                <ol>
                                    <li>
                                        <label for="hostname-mode">{{
                                            $__("Connection mode")
                                        }}</label>
                                        <select
                                            id="hostname-mode"
                                            class="form-select"
                                            v-model="hostnameMode"
                                        >
                                            <option value="not_applicable">
                                                {{ $__("Not applicable") }}
                                            </option>
                                            <option value="optional">
                                                {{
                                                    $__(
                                                        "Optional (shown as login option)"
                                                    )
                                                }}
                                            </option>
                                            <option value="active">
                                                {{
                                                    $__(
                                                        "Active (primary option)"
                                                    )
                                                }}
                                            </option>
                                        </select>
                                    </li>
                                    <li
                                        v-if="hostnameMode !== 'not_applicable'"
                                    >
                                        <label for="hostname-force-sso-opac">{{
                                            $__("Force SSO (OPAC)")
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input
                                                class="form-check-input"
                                                type="checkbox"
                                                id="hostname-force-sso-opac"
                                                v-model="hostnameForceSsoOpac"
                                                role="switch"
                                            />
                                        </div>
                                        <span class="text-muted">{{
                                            $__(
                                                "Automatically redirect OPAC users on this hostname to this provider"
                                            )
                                        }}</span>
                                    </li>
                                    <li
                                        v-if="
                                            hostnameMode !== 'not_applicable' &&
                                            hostnameForceSsoOpac &&
                                            selectedHostname.conflict_sso_opac
                                                .length
                                        "
                                    >
                                        <label></label>
                                        <div
                                            class="alert alert-warning py-2 mb-0"
                                        >
                                            <i
                                                class="fa fa-exclamation-triangle"
                                            ></i>
                                            {{
                                                $__(
                                                    "Force SSO (OPAC) is already enabled for this hostname by: %s"
                                                ).replace(
                                                    "%s",
                                                    selectedHostname.conflict_sso_opac.join(
                                                        ", "
                                                    )
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li
                                        v-if="hostnameMode !== 'not_applicable'"
                                    >
                                        <label for="hostname-force-sso-staff">{{
                                            $__("Force SSO (staff)")
                                        }}</label>
                                        <div class="form-check form-switch">
                                            <input
                                                class="form-check-input"
                                                type="checkbox"
                                                id="hostname-force-sso-staff"
                                                v-model="hostnameForceSsoStaff"
                                                role="switch"
                                            />
                                        </div>
                                        <span class="text-muted">{{
                                            $__(
                                                "Automatically redirect staff users on this hostname to this provider"
                                            )
                                        }}</span>
                                    </li>
                                    <li
                                        v-if="
                                            hostnameMode !== 'not_applicable' &&
                                            hostnameForceSsoStaff &&
                                            selectedHostname.conflict_sso_staff
                                                .length
                                        "
                                    >
                                        <label></label>
                                        <div
                                            class="alert alert-warning py-2 mb-0"
                                        >
                                            <i
                                                class="fa fa-exclamation-triangle"
                                            ></i>
                                            {{
                                                $__(
                                                    "Force SSO (staff) is already enabled for this hostname by: %s"
                                                ).replace(
                                                    "%s",
                                                    selectedHostname.conflict_sso_staff.join(
                                                        ", "
                                                    )
                                                )
                                            }}
                                        </div>
                                    </li>
                                </ol>
                            </fieldset>

                            <div class="d-flex gap-2 mt-2">
                                <button
                                    type="button"
                                    class="btn btn-primary btn-sm"
                                    @click="saveHostnameMode"
                                    :disabled="savingHostname"
                                >
                                    {{
                                        savingHostname
                                            ? $__("Saving...")
                                            : $__("Save")
                                    }}
                                </button>
                                <button
                                    v-if="selectedHostname.is_linked"
                                    type="button"
                                    class="btn btn-danger btn-sm"
                                    @click="removeHostname(selectedHostname)"
                                >
                                    <i class="fa fa-unlink"></i>
                                    {{ $__("Remove") }}
                                </button>
                            </div>
                        </template>
                    </div>
                </div>

                <fieldset class="action">
                    <a
                        class="cancel"
                        href="#"
                        @click.prevent="doneEditSection2"
                        >{{ $__("Done") }}</a
                    >
                </fieldset>
            </template>
        </div>

        <!-- ─────────────────────────────────────────────────────────── -->
        <!-- Section 3: Attribute Mappings                              -->
        <!-- ─────────────────────────────────────────────────────────── -->
        <div class="page-section">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h2>
                    <i class="fa fa-exchange-alt"></i>
                    {{ $__("3. Attribute Mappings") }}
                </h2>
                <button
                    v-if="!editingSection3"
                    type="button"
                    class="btn btn-default"
                    @click="editingSection3 = true"
                >
                    <i class="fa fa-pencil"></i>
                    {{ $__("Edit") }}
                </button>
            </div>
            <p class="text-muted">
                {{
                    $__(
                        "Map incoming identity provider attributes to Koha patron fields."
                    )
                }}
            </p>

            <div v-if="mappingsLoading" class="text-muted">
                {{ $__("Loading...") }}
            </div>

            <!-- VIEW MODE: read-only table -->
            <template v-else-if="!editingSection3">
                <table class="table table-bordered table-sm">
                    <thead class="table-light">
                        <tr>
                            <th>{{ $__("IdP field") }}</th>
                            <th>{{ $__("Koha field") }}</th>
                            <th class="text-center">
                                {{ $__("Matchpoint") }}
                            </th>
                            <th>{{ $__("Default value") }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr
                            v-for="mapping in mappings"
                            :key="mapping.mapping_id"
                            :class="{
                                'table-primary': mapping.is_matchpoint,
                            }"
                        >
                            <td>{{ mapping.provider_field }}</td>
                            <td>{{ mapping.koha_field }}</td>
                            <td class="text-center">
                                <span
                                    v-if="mapping.is_matchpoint"
                                    class="badge bg-primary"
                                    >{{ $__("Yes") }}</span
                                >
                                <span v-else class="badge bg-secondary">{{
                                    $__("No")
                                }}</span>
                            </td>
                            <td>{{ mapping.default_content || "—" }}</td>
                        </tr>
                        <tr v-if="mappings.length === 0">
                            <td colspan="4" class="text-muted text-center">
                                {{ $__("No attribute mappings defined.") }}
                            </td>
                        </tr>
                    </tbody>
                </table>
            </template>

            <!-- EDIT MODE: editable table with per-row save -->
            <template v-else>
                <table class="table table-bordered table-sm">
                    <thead class="table-light">
                        <tr>
                            <th>{{ $__("IdP field") }}</th>
                            <th>{{ $__("Koha field") }}</th>
                            <th class="text-center">
                                {{ $__("Matchpoint") }}
                            </th>
                            <th>{{ $__("Default value") }}</th>
                            <th class="text-center">
                                {{ $__("Required") }}
                            </th>
                            <th class="text-center">
                                {{ $__("Actions") }}
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr
                            v-for="(mapping, idx) in mappings"
                            :key="
                                mapping.mapping_id
                                    ? 'row-' + mapping.mapping_id
                                    : 'unsaved-' + idx
                            "
                            :class="{
                                'table-primary': mapping.is_matchpoint,
                            }"
                        >
                            <td>
                                <input
                                    type="text"
                                    class="form-control form-control-sm"
                                    v-model="mapping.provider_field"
                                    :placeholder="$__('e.g. given_name')"
                                />
                            </td>
                            <td>
                                <select
                                    class="form-select form-select-sm"
                                    v-model="mapping.koha_field"
                                >
                                    <option
                                        v-for="col in borrowerColumns"
                                        :key="col.value"
                                        :value="col.value"
                                    >
                                        {{ col.label }}
                                    </option>
                                </select>
                            </td>
                            <td class="text-center align-middle">
                                <div
                                    class="form-check form-switch d-flex justify-content-center mb-0"
                                >
                                    <input
                                        class="form-check-input"
                                        type="checkbox"
                                        v-model="mapping.is_matchpoint"
                                        @change="onMatchpointChange(idx)"
                                        role="switch"
                                    />
                                </div>
                            </td>
                            <td>
                                <input
                                    type="text"
                                    class="form-control form-control-sm"
                                    v-model="mapping.default_content"
                                    :placeholder="$__('Default')"
                                />
                            </td>
                            <td class="text-center align-middle">
                                <span
                                    v-if="mapping.is_matchpoint"
                                    class="badge bg-primary"
                                    >{{ $__("Required") }}</span
                                >
                                <span v-else class="badge bg-secondary">{{
                                    $__("Optional")
                                }}</span>
                            </td>
                            <td class="text-center align-middle text-nowrap">
                                <button
                                    type="button"
                                    class="btn btn-success btn-sm"
                                    :title="$__('Save')"
                                    @click="saveMapping(mapping)"
                                >
                                    <i class="fa fa-save"></i>
                                </button>
                                <button
                                    type="button"
                                    class="btn btn-danger btn-sm ms-1"
                                    :title="$__('Delete')"
                                    @click="confirmDeleteMapping(mapping, idx)"
                                >
                                    <i class="fa fa-trash"></i>
                                </button>
                            </td>
                        </tr>

                        <!-- New mapping row -->
                        <tr v-if="addingMapping" class="table-success">
                            <td>
                                <input
                                    ref="newMappingInput"
                                    type="text"
                                    class="form-control form-control-sm"
                                    v-model="newMapping.provider_field"
                                    :placeholder="$__('e.g. given_name')"
                                />
                            </td>
                            <td>
                                <select
                                    class="form-select form-select-sm"
                                    v-model="newMapping.koha_field"
                                >
                                    <option value="">
                                        {{ $__("-- Select field --") }}
                                    </option>
                                    <option
                                        v-for="col in borrowerColumns"
                                        :key="col.value"
                                        :value="col.value"
                                    >
                                        {{ col.label }}
                                    </option>
                                </select>
                            </td>
                            <td class="text-center align-middle">
                                <div
                                    class="form-check form-switch d-flex justify-content-center mb-0"
                                >
                                    <input
                                        class="form-check-input"
                                        type="checkbox"
                                        v-model="newMapping.is_matchpoint"
                                        role="switch"
                                    />
                                </div>
                            </td>
                            <td>
                                <input
                                    type="text"
                                    class="form-control form-control-sm"
                                    v-model="newMapping.default_content"
                                    :placeholder="$__('Default')"
                                />
                            </td>
                            <td></td>
                            <td class="text-center align-middle text-nowrap">
                                <button
                                    type="button"
                                    class="btn btn-success btn-sm"
                                    :title="$__('Save')"
                                    @click="saveNewMapping"
                                >
                                    <i class="fa fa-check"></i>
                                </button>
                                <button
                                    type="button"
                                    class="btn btn-default btn-sm ms-1"
                                    :title="$__('Cancel')"
                                    @click="cancelNewMapping"
                                >
                                    <i class="fa fa-times"></i>
                                </button>
                            </td>
                        </tr>

                        <tr v-if="mappings.length === 0 && !addingMapping">
                            <td colspan="6" class="text-muted text-center">
                                {{ $__("No attribute mappings defined.") }}
                            </td>
                        </tr>
                    </tbody>
                </table>

                <div class="d-flex justify-content-between align-items-center">
                    <button
                        v-if="!addingMapping"
                        type="button"
                        class="btn btn-default btn-sm"
                        @click="startAddMapping"
                    >
                        <i class="fa fa-plus"></i>
                        {{ $__("Add mapping") }}
                    </button>
                    <span v-else></span>
                    <a
                        class="cancel"
                        href="#"
                        @click.prevent="doneEditSection3"
                        >{{ $__("Done") }}</a
                    >
                </div>
            </template>
        </div>

        <!-- ─────────────────────────────────────────────────────────── -->
        <!-- Section 4: Domain Logic Handling                           -->
        <!-- ─────────────────────────────────────────────────────────── -->
        <div class="page-section">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h2>
                    <i class="fa fa-globe"></i>
                    {{ $__("4. Domain Logic Handling") }}
                </h2>
                <button
                    v-if="!editingSection4"
                    type="button"
                    class="btn btn-default"
                    @click="startEditSection4"
                >
                    <i class="fa fa-pencil"></i>
                    {{ $__("Edit") }}
                </button>
            </div>
            <p class="text-muted">
                {{
                    $__(
                        "Automate user provisioning and access control based on email domain."
                    )
                }}
            </p>

            <div v-if="domainsLoading" class="text-muted">
                {{ $__("Loading...") }}
            </div>

            <!-- VIEW MODE: read-only domain list -->
            <template v-else-if="!editingSection4">
                <ul class="list-group">
                    <li
                        v-for="domain in domains"
                        :key="domain.identity_provider_domain_id"
                        class="list-group-item"
                    >
                        <div
                            class="d-flex justify-content-between align-items-center"
                        >
                            <strong>{{
                                domain.domain || $__("(any domain)")
                            }}</strong>
                            <span class="d-flex gap-1">
                                <span
                                    v-if="domain.allow_opac"
                                    class="badge bg-secondary"
                                    >{{ $__("OPAC") }}</span
                                >
                                <span
                                    v-if="domain.allow_staff"
                                    class="badge bg-secondary"
                                    >{{ $__("Staff") }}</span
                                >
                                <span
                                    v-if="
                                        domain.auto_register_opac ||
                                        domain.auto_register_staff
                                    "
                                    class="badge bg-info text-dark"
                                    >{{ $__("Auto-register") }}</span
                                >
                            </span>
                        </div>
                        <small
                            v-if="domain.default_library_id"
                            class="text-muted"
                        >
                            {{
                                $__("Default library: %s").replace(
                                    "%s",
                                    libraryLabel(domain.default_library_id)
                                )
                            }}
                        </small>
                    </li>
                    <li
                        v-if="domains.length === 0"
                        class="list-group-item text-muted"
                    >
                        {{ $__("No domain rules configured.") }}
                    </li>
                </ul>
            </template>

            <!-- EDIT MODE: full interactive split panel -->
            <template v-else>
                <div class="row g-0 border rounded">
                    <!-- Left: domains list -->
                    <div class="col-md-3 border-end bg-light">
                        <div
                            class="list-group list-group-flush"
                            style="max-height: 360px; overflow-y: auto"
                        >
                            <button
                                v-for="domain in domains"
                                :key="
                                    domain.identity_provider_domain_id ||
                                    'new-domain'
                                "
                                type="button"
                                class="list-group-item list-group-item-action d-flex justify-content-between align-items-center py-2"
                                :class="{
                                    active:
                                        selectedDomain?.identity_provider_domain_id ===
                                            domain.identity_provider_domain_id &&
                                        domain.identity_provider_domain_id !==
                                            null,
                                }"
                                @click="selectDomain(domain)"
                            >
                                <span class="text-truncate me-2 small">
                                    {{ domain.domain || $__("(any domain)") }}
                                </span>
                                <span
                                    v-if="!domain.identity_provider_domain_id"
                                    class="badge bg-warning text-dark flex-shrink-0"
                                    >{{ $__("Unsaved") }}</span
                                >
                            </button>
                            <div
                                v-if="domains.length === 0"
                                class="list-group-item text-muted small"
                            >
                                {{ $__("No domain rules configured.") }}
                            </div>
                        </div>
                        <div class="p-2 border-top">
                            <button
                                type="button"
                                class="btn btn-sm btn-default w-100"
                                @click="addDomain"
                            >
                                <i class="fa fa-plus"></i>
                                {{ $__("Add Domain") }}
                            </button>
                        </div>
                    </div>

                    <!-- Right: domain configuration -->
                    <div class="col-md-9 p-3">
                        <div
                            v-if="!selectedDomain"
                            class="d-flex align-items-center justify-content-center h-100 text-muted"
                            style="min-height: 200px"
                        >
                            {{ $__("Select a domain to configure its rules") }}
                        </div>
                        <template v-else>
                            <h5>
                                {{ $__("Domain Rules") }}:
                                <code>{{
                                    selectedDomain.domain || $__("(any domain)")
                                }}</code>
                            </h5>

                            <fieldset class="rows">
                                <ol>
                                    <li>
                                        <label
                                            :for="`domain-pattern-${domainEditKey}`"
                                        >
                                            {{ $__("Domain pattern") }}
                                        </label>
                                        <input
                                            :id="`domain-pattern-${domainEditKey}`"
                                            type="text"
                                            class="form-control"
                                            v-model="domainEdit.domain"
                                            :placeholder="
                                                $__(
                                                    'e.g. university.edu or * for any'
                                                )
                                            "
                                        />
                                    </li>
                                </ol>
                            </fieldset>

                            <div class="row">
                                <div class="col-md-6">
                                    <fieldset class="rows">
                                        <legend>
                                            {{ $__("Access control") }}
                                        </legend>
                                        <ol class="radio">
                                            <li>
                                                <label>
                                                    <input
                                                        type="checkbox"
                                                        :id="`allow_opac_${domainEditKey}`"
                                                        v-model="
                                                            domainEdit.allow_opac
                                                        "
                                                    />
                                                    {{
                                                        $__("Allow OPAC login")
                                                    }}
                                                </label>
                                            </li>
                                            <li>
                                                <label>
                                                    <input
                                                        type="checkbox"
                                                        :id="`allow_staff_${domainEditKey}`"
                                                        v-model="
                                                            domainEdit.allow_staff
                                                        "
                                                    />
                                                    {{
                                                        $__("Allow staff login")
                                                    }}
                                                </label>
                                            </li>
                                        </ol>
                                    </fieldset>
                                </div>
                                <div class="col-md-6">
                                    <fieldset class="rows">
                                        <legend>
                                            {{ $__("Auto-registration") }}
                                        </legend>
                                        <ol class="radio">
                                            <li>
                                                <label>
                                                    <input
                                                        type="checkbox"
                                                        :id="`auto_opac_${domainEditKey}`"
                                                        v-model="
                                                            domainEdit.auto_register_opac
                                                        "
                                                    />
                                                    {{
                                                        $__(
                                                            "Auto-create patron (OPAC)"
                                                        )
                                                    }}
                                                </label>
                                            </li>
                                            <li>
                                                <label>
                                                    <input
                                                        type="checkbox"
                                                        :id="`auto_staff_${domainEditKey}`"
                                                        v-model="
                                                            domainEdit.auto_register_staff
                                                        "
                                                    />
                                                    {{
                                                        $__(
                                                            "Auto-create patron (staff)"
                                                        )
                                                    }}
                                                </label>
                                            </li>
                                            <li>
                                                <label>
                                                    <input
                                                        type="checkbox"
                                                        :id="`update_${domainEditKey}`"
                                                        v-model="
                                                            domainEdit.update_on_auth
                                                        "
                                                    />
                                                    {{
                                                        $__(
                                                            "Update patron data on login"
                                                        )
                                                    }}
                                                </label>
                                            </li>
                                        </ol>
                                    </fieldset>
                                </div>
                            </div>

                            <fieldset class="rows">
                                <ol>
                                    <li>
                                        <label
                                            :for="`default_library_${domainEditKey}`"
                                        >
                                            {{ $__("Default library") }}
                                        </label>
                                        <select
                                            :id="`default_library_${domainEditKey}`"
                                            class="form-select"
                                            v-model="
                                                domainEdit.default_library_id
                                            "
                                        >
                                            <option :value="null">
                                                {{ $__("-- None --") }}
                                            </option>
                                            <option
                                                v-for="lib in libraries"
                                                :key="lib.value"
                                                :value="lib.value"
                                            >
                                                {{ lib.label }}
                                            </option>
                                        </select>
                                    </li>
                                    <li>
                                        <label
                                            :for="`default_category_${domainEditKey}`"
                                        >
                                            {{ $__("Default category") }}
                                        </label>
                                        <select
                                            :id="`default_category_${domainEditKey}`"
                                            class="form-select"
                                            v-model="
                                                domainEdit.default_category_id
                                            "
                                        >
                                            <option :value="null">
                                                {{ $__("-- None --") }}
                                            </option>
                                            <option
                                                v-for="cat in categories"
                                                :key="cat.value"
                                                :value="cat.value"
                                            >
                                                {{ cat.label }}
                                            </option>
                                        </select>
                                    </li>
                                </ol>
                            </fieldset>

                            <div class="d-flex justify-content-between mt-2">
                                <button
                                    type="button"
                                    class="btn btn-danger btn-sm"
                                    @click="confirmDeleteDomain(selectedDomain)"
                                >
                                    <i class="fa fa-trash"></i>
                                    {{ $__("Delete domain") }}
                                </button>
                                <button
                                    type="button"
                                    class="btn btn-primary btn-sm"
                                    @click="saveDomain"
                                    :disabled="savingDomain"
                                >
                                    {{
                                        savingDomain
                                            ? $__("Saving...")
                                            : $__("Save domain rules")
                                    }}
                                </button>
                            </div>
                        </template>
                    </div>
                </div>

                <fieldset class="action">
                    <a
                        class="cancel"
                        href="#"
                        @click.prevent="doneEditSection4"
                        >{{ $__("Done") }}</a
                    >
                </fieldset>
            </template>
        </div>
    </div>
</template>

<script>
import { ref, computed, inject, onMounted, nextTick } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

const PROTOCOL_CONFIG_FIELDS = {
    OAuth: [
        {
            name: "key",
            label: $__("Client ID"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "secret",
            label: $__("Client secret"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "authorize_url",
            label: $__("Authorization URL"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "token_url",
            label: $__("Token URL"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "userinfo_url",
            label: $__("User info URL"),
            required: false,
            type: "text",
            toolTip: "",
        },
        {
            name: "scope",
            label: $__("Scope"),
            required: false,
            type: "text",
            toolTip: $__(
                "Space-separated list of scopes, e.g. 'email profile'"
            ),
        },
    ],
    OIDC: [
        {
            name: "key",
            label: $__("Client ID"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "secret",
            label: $__("Client secret"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "well_known_url",
            label: $__("Well-known URL"),
            required: true,
            type: "text",
            toolTip: $__("OpenID Connect discovery endpoint"),
        },
        {
            name: "scope",
            label: $__("Scope"),
            required: false,
            type: "text",
            toolTip: $__(
                "Space-separated list of scopes, e.g. 'openid email profile'"
            ),
        },
    ],
    SAML2: [
        {
            name: "autocreate",
            label: $__("Auto-create patrons"),
            required: false,
            type: "boolean",
            toolTip: $__(
                "Automatically create a patron record for new Shibboleth users"
            ),
        },
        {
            name: "sync",
            label: $__("Sync attributes on login"),
            required: false,
            type: "boolean",
            toolTip: $__("Update patron attributes from the IdP on each login"),
        },
        {
            name: "welcome",
            label: $__("Send welcome email"),
            required: false,
            type: "boolean",
            toolTip: $__("Send a welcome email to newly auto-created patrons"),
        },
    ],
    CAS: [
        {
            name: "server_url",
            label: $__("CAS server URL"),
            required: true,
            type: "text",
            toolTip: "",
        },
        {
            name: "login_url",
            label: $__("Login URL"),
            required: false,
            type: "text",
            toolTip: "",
        },
        {
            name: "validate_url",
            label: $__("Validate URL"),
            required: false,
            type: "text",
            toolTip: "",
        },
    ],
};

export default {
    name: "ProviderWorkspace",
    props: {
        providerId: {
            type: Number,
            required: true,
        },
    },
    setup(props) {
        const mainStore = inject("mainStore");
        const { setMessage, setError, setConfirmationDialog } = mainStore;

        const initialized = ref(false);
        const hostnamesLoading = ref(true);
        const mappingsLoading = ref(true);
        const domainsLoading = ref(true);

        // ── Section edit state ─────────────────────────────────────────
        const editingSection1 = ref(false);
        const editingSection2 = ref(false);
        const editingSection3 = ref(false);
        const editingSection4 = ref(false);
        const savingSection1 = ref(false);
        const savingHostname = ref(false);
        const savingDomain = ref(false);

        // ── Section 1: Provider ────────────────────────────────────────
        const provider = ref({});
        const configData = ref({});
        const configFields = computed(
            () => PROTOCOL_CONFIG_FIELDS[provider.value.protocol] || []
        );

        // Editable copies for Section 1 (so Cancel can revert without an API call)
        const providerEdit = ref({});
        const configDataEdit = ref({});
        const configFieldsForEdit = computed(
            () => PROTOCOL_CONFIG_FIELDS[providerEdit.value.protocol] || []
        );

        const startEditSection1 = () => {
            providerEdit.value = { ...provider.value };
            configDataEdit.value = { ...configData.value };
            editingSection1.value = true;
        };

        const cancelSection1 = () => {
            editingSection1.value = false;
        };

        const onProtocolChangeEdit = () => {
            const fields =
                PROTOCOL_CONFIG_FIELDS[providerEdit.value.protocol] || [];
            const fresh = {};
            fields.forEach(f => {
                fresh[f.name] = f.type === "boolean" ? false : "";
            });
            configDataEdit.value = fresh;
        };

        // Keep the original onProtocolChange for any legacy usage
        const onProtocolChange = () => {
            const fields =
                PROTOCOL_CONFIG_FIELDS[provider.value.protocol] || [];
            const fresh = {};
            fields.forEach(f => {
                fresh[f.name] = f.type === "boolean" ? false : "";
            });
            configData.value = fresh;
        };

        const saveSection1 = async () => {
            savingSection1.value = true;
            try {
                const data = { ...providerEdit.value };
                delete data.identity_provider_id;
                // force_sso is managed at the hostname level, not the provider level
                delete data.force_sso_opac;
                delete data.force_sso_staff;

                const fields = PROTOCOL_CONFIG_FIELDS[data.protocol] || [];
                const config = {};
                fields.forEach(f => {
                    config[f.name] = configDataEdit.value[f.name];
                });
                data.config = config;

                await APIClient.identity_providers.providers.update(
                    data,
                    props.providerId
                );

                // Update canonical state from the edit copies
                provider.value = { ...provider.value, ...providerEdit.value };
                configData.value = { ...configDataEdit.value };

                setMessage($__("Identity provider settings saved"));
                editingSection1.value = false;
            } catch (e) {
                // errors surfaced by httpClient
            } finally {
                savingSection1.value = false;
            }
        };

        // ── Section 2: Hostnames ───────────────────────────────────────
        const allHostnameRows = ref([]);
        const allProviders = ref([]);
        const selectedHostname = ref(null);
        const hostnameMode = ref("not_applicable");
        const hostnameForceSsoOpac = ref(false);
        const hostnameForceSsoStaff = ref(false);
        const defaultHostnames = window.idp_default_hostnames || [];

        const hostnameRows = computed(() => {
            const byHostname = {};

            defaultHostnames.forEach(h => {
                byHostname[h] = {
                    hostname: h,
                    hostname_id: null,
                    is_linked: false,
                    is_enabled: false,
                    force_sso_opac: false,
                    force_sso_staff: false,
                    other_providers: [],
                    conflict_sso_opac: [],
                    conflict_sso_staff: [],
                };
            });

            allHostnameRows.value.forEach(row => {
                if (!byHostname[row.hostname]) {
                    byHostname[row.hostname] = {
                        hostname: row.hostname,
                        hostname_id: null,
                        is_linked: false,
                        is_enabled: false,
                        force_sso_opac: false,
                        force_sso_staff: false,
                        other_providers: [],
                        conflict_sso_opac: [],
                        conflict_sso_staff: [],
                    };
                }
                const p = allProviders.value.find(
                    p => p.identity_provider_id === row.identity_provider_id
                );
                const pName = p
                    ? p.description
                    : `#${row.identity_provider_id}`;

                if (row.identity_provider_id === props.providerId) {
                    byHostname[row.hostname].hostname_id =
                        row.identity_provider_hostname_id;
                    byHostname[row.hostname].is_linked = true;
                    byHostname[row.hostname].is_enabled = row.is_enabled;
                    byHostname[row.hostname].force_sso_opac =
                        row.force_sso_opac || false;
                    byHostname[row.hostname].force_sso_staff =
                        row.force_sso_staff || false;
                } else {
                    byHostname[row.hostname].other_providers.push(pName);
                    if (row.force_sso_opac)
                        byHostname[row.hostname].conflict_sso_opac.push(pName);
                    if (row.force_sso_staff)
                        byHostname[row.hostname].conflict_sso_staff.push(pName);
                }
            });

            return Object.values(byHostname).sort((a, b) => {
                if (a.is_linked !== b.is_linked) return a.is_linked ? -1 : 1;
                if (a.is_linked && a.is_enabled !== b.is_enabled)
                    return a.is_enabled ? -1 : 1;
                return a.hostname.localeCompare(b.hostname);
            });
        });

        const startEditSection2 = () => {
            selectedHostname.value = null;
            editingSection2.value = true;
        };

        const doneEditSection2 = () => {
            selectedHostname.value = null;
            editingSection2.value = false;
        };

        const selectHostname = row => {
            selectedHostname.value = row;
            if (!row.is_linked) {
                hostnameMode.value = "not_applicable";
                hostnameForceSsoOpac.value = false;
                hostnameForceSsoStaff.value = false;
            } else {
                hostnameMode.value = row.is_enabled ? "active" : "optional";
                hostnameForceSsoOpac.value = row.force_sso_opac || false;
                hostnameForceSsoStaff.value = row.force_sso_staff || false;
            }
        };

        const saveHostnameMode = async () => {
            savingHostname.value = true;
            try {
                const row = selectedHostname.value;
                if (hostnameMode.value === "not_applicable") {
                    if (row.is_linked) {
                        await APIClient.identity_providers.hostnames.delete(
                            row.hostname_id
                        );
                    }
                } else {
                    const isEnabled = hostnameMode.value === "active";
                    const payload = {
                        hostname: row.hostname,
                        identity_provider_id: props.providerId,
                        is_enabled: isEnabled,
                        force_sso_opac: hostnameForceSsoOpac.value,
                        force_sso_staff: hostnameForceSsoStaff.value,
                    };
                    if (row.is_linked) {
                        await APIClient.identity_providers.hostnames.update(
                            payload,
                            row.hostname_id
                        );
                    } else {
                        await APIClient.identity_providers.hostnames.create(
                            payload
                        );
                    }
                }
                setMessage($__("Hostname configuration saved"));
                await reloadHostnames();
                const updated = hostnameRows.value.find(
                    r => r.hostname === row.hostname
                );
                if (updated) selectedHostname.value = updated;
            } catch (e) {
                // errors surfaced by httpClient
            } finally {
                savingHostname.value = false;
            }
        };

        const removeHostname = row => {
            setConfirmationDialog(
                {
                    title: $__("Remove hostname"),
                    message: $__("Remove '%s' from this provider?").replace(
                        "%s",
                        row.hostname
                    ),
                    accept_label: $__("Yes, remove"),
                    cancel_label: $__("Cancel"),
                },
                async () => {
                    await APIClient.identity_providers.hostnames.delete(
                        row.hostname_id
                    );
                    setMessage($__("Hostname removed from this provider"));
                    selectedHostname.value = null;
                    await reloadHostnames();
                }
            );
        };

        const openAddHostnameDialog = () => {
            setConfirmationDialog(
                {
                    title: $__("Add hostname"),
                    accept_label: $__("Add"),
                    cancel_label: $__("Cancel"),
                    inputs: [
                        {
                            name: "hostname",
                            type: "text",
                            label: $__("Hostname"),
                            required: true,
                            value: "",
                        },
                    ],
                },
                async (confirmed, inputFields) => {
                    const hostname = (inputFields.hostname || "").trim();
                    if (!hostname) return;
                    await APIClient.identity_providers.hostnames.create({
                        hostname,
                        identity_provider_id: props.providerId,
                        is_enabled: true,
                    });
                    setMessage($__("Hostname added"));
                    await reloadHostnames();
                    const added = hostnameRows.value.find(
                        r => r.hostname === hostname
                    );
                    if (added) selectHostname(added);
                }
            );
        };

        const reloadHostnames = async () => {
            allHostnameRows.value =
                await APIClient.identity_providers.hostnames.getAll();
        };

        // ── Section 3: Mappings ────────────────────────────────────────
        const mappings = ref([]);
        const addingMapping = ref(false);
        const newMapping = ref({});
        const newMappingInput = ref(null);
        const borrowerColumns = window.borrower_columns || [];

        const doneEditSection3 = () => {
            addingMapping.value = false;
            newMapping.value = {};
            editingSection3.value = false;
        };

        const onMatchpointChange = idx => {
            if (mappings.value[idx].is_matchpoint) {
                mappings.value.forEach((m, i) => {
                    if (i !== idx) m.is_matchpoint = false;
                });
            }
        };

        const saveMapping = async mapping => {
            try {
                await APIClient.identity_providers.mappings.update(
                    props.providerId,
                    {
                        provider_field: mapping.provider_field || null,
                        koha_field: mapping.koha_field,
                        default_content: mapping.default_content || null,
                        is_matchpoint: mapping.is_matchpoint || false,
                    },
                    mapping.mapping_id
                );
                setMessage($__("Mapping updated"));
                await reloadMappings();
            } catch (e) {
                // errors surfaced by httpClient
            }
        };

        const confirmDeleteMapping = (mapping, idx) => {
            if (!mapping.mapping_id) {
                mappings.value.splice(idx, 1);
                return;
            }
            setConfirmationDialog(
                {
                    title: $__("Delete mapping"),
                    message: $__(
                        "Are you sure you want to remove this field mapping?"
                    ),
                    accept_label: $__("Yes, delete"),
                    cancel_label: $__("Cancel"),
                },
                async () => {
                    await APIClient.identity_providers.mappings.delete(
                        props.providerId,
                        mapping.mapping_id
                    );
                    setMessage($__("Mapping deleted"));
                    await reloadMappings();
                }
            );
        };

        const startAddMapping = () => {
            addingMapping.value = true;
            newMapping.value = {
                provider_field: "",
                koha_field: borrowerColumns[0]?.value || "",
                default_content: "",
                is_matchpoint: false,
            };
            nextTick(() => {
                if (newMappingInput.value) newMappingInput.value.focus();
            });
        };

        const saveNewMapping = async () => {
            try {
                await APIClient.identity_providers.mappings.create(
                    props.providerId,
                    {
                        provider_field: newMapping.value.provider_field || null,
                        koha_field: newMapping.value.koha_field,
                        default_content:
                            newMapping.value.default_content || null,
                        is_matchpoint: newMapping.value.is_matchpoint || false,
                    }
                );
                setMessage($__("Mapping created"));
                addingMapping.value = false;
                newMapping.value = {};
                await reloadMappings();
            } catch (e) {
                // errors surfaced by httpClient
            }
        };

        const cancelNewMapping = () => {
            addingMapping.value = false;
            newMapping.value = {};
        };

        const reloadMappings = async () => {
            mappings.value = await APIClient.identity_providers.mappings.getAll(
                props.providerId
            );
        };

        // ── Section 4: Domains ─────────────────────────────────────────
        const domains = ref([]);
        const selectedDomain = ref(null);
        const domainEdit = ref({});
        const domainEditKey = ref(0);
        const libraries = window.libraries_map || [];
        const categories = window.categories_map || [];

        const libraryLabel = id => {
            const lib = libraries.find(l => l.value === id);
            return lib ? lib.label : id;
        };

        const startEditSection4 = () => {
            selectedDomain.value = null;
            domainEdit.value = {};
            editingSection4.value = true;
        };

        const doneEditSection4 = () => {
            selectedDomain.value = null;
            domainEdit.value = {};
            editingSection4.value = false;
        };

        const selectDomain = domain => {
            selectedDomain.value = domain;
            domainEdit.value = { ...domain };
            domainEditKey.value++;
        };

        const addDomain = () => {
            const newDom = {
                identity_provider_domain_id: null,
                domain: "",
                allow_opac: true,
                allow_staff: false,
                auto_register_opac: false,
                auto_register_staff: false,
                update_on_auth: false,
                default_library_id: null,
                default_category_id: null,
            };
            domains.value.push(newDom);
            selectDomain(newDom);
        };

        const saveDomain = async () => {
            savingDomain.value = true;
            try {
                const data = { ...domainEdit.value };
                const domainId = data.identity_provider_domain_id;
                delete data.identity_provider_domain_id;
                delete data.identity_provider_id;

                if (domainId) {
                    await APIClient.identity_providers.domains.update(
                        props.providerId,
                        data,
                        domainId
                    );
                    setMessage($__("Domain updated"));
                } else {
                    await APIClient.identity_providers.domains.create(
                        props.providerId,
                        data
                    );
                    setMessage($__("Domain created"));
                }

                await reloadDomains();
                const saved = domainId
                    ? domains.value.find(
                          d => d.identity_provider_domain_id === domainId
                      )
                    : domains.value[domains.value.length - 1];
                if (saved) selectDomain(saved);
            } catch (e) {
                // errors surfaced by httpClient
            } finally {
                savingDomain.value = false;
            }
        };

        const confirmDeleteDomain = domain => {
            if (!domain.identity_provider_domain_id) {
                domains.value = domains.value.filter(d => d !== domain);
                selectedDomain.value = null;
                return;
            }
            setConfirmationDialog(
                {
                    title: $__("Delete domain"),
                    message: $__(
                        "Are you sure you want to remove the domain configuration for '%s'?"
                    ).replace("%s", domain.domain || $__("(any domain)")),
                    accept_label: $__("Yes, delete"),
                    cancel_label: $__("Cancel"),
                },
                async () => {
                    await APIClient.identity_providers.domains.delete(
                        props.providerId,
                        domain.identity_provider_domain_id
                    );
                    setMessage($__("Domain deleted"));
                    selectedDomain.value = null;
                    domainEdit.value = {};
                    await reloadDomains();
                }
            );
        };

        const reloadDomains = async () => {
            domains.value = await APIClient.identity_providers.domains.getAll(
                props.providerId
            );
        };

        // ── Initial load ───────────────────────────────────────────────
        onMounted(async () => {
            try {
                const [providerData, hostnameList, allProvidersList] =
                    await Promise.all([
                        APIClient.identity_providers.providers.get(
                            props.providerId
                        ),
                        APIClient.identity_providers.hostnames.getAll(),
                        APIClient.identity_providers.providers.getAll(),
                    ]);

                provider.value = providerData;

                const config = providerData.config || {};
                const fields =
                    PROTOCOL_CONFIG_FIELDS[providerData.protocol] || [];
                const cdata = {};
                fields.forEach(f => {
                    cdata[f.name] =
                        f.type === "boolean"
                            ? (config[f.name] ?? false)
                            : (config[f.name] ?? "");
                });
                configData.value = cdata;

                allHostnameRows.value = hostnameList;
                allProviders.value = allProvidersList;
                hostnamesLoading.value = false;

                const [mappingList, domainList] = await Promise.all([
                    APIClient.identity_providers.mappings.getAll(
                        props.providerId
                    ),
                    APIClient.identity_providers.domains.getAll(
                        props.providerId
                    ),
                ]);
                mappings.value = mappingList;
                domains.value = domainList;
                mappingsLoading.value = false;
                domainsLoading.value = false;

                initialized.value = true;
            } catch (e) {
                setError($__("Failed to load identity provider configuration"));
            }
        });

        return {
            initialized,
            hostnamesLoading,
            mappingsLoading,
            domainsLoading,
            // Section edit state
            editingSection1,
            editingSection2,
            editingSection3,
            editingSection4,
            savingSection1,
            savingHostname,
            savingDomain,
            // Section 1
            provider,
            configData,
            configFields,
            providerEdit,
            configDataEdit,
            configFieldsForEdit,
            startEditSection1,
            cancelSection1,
            onProtocolChange,
            onProtocolChangeEdit,
            saveSection1,
            // Section 2
            hostnameRows,
            selectedHostname,
            hostnameMode,
            hostnameForceSsoOpac,
            hostnameForceSsoStaff,
            startEditSection2,
            doneEditSection2,
            selectHostname,
            saveHostnameMode,
            removeHostname,
            openAddHostnameDialog,
            // Section 3
            mappings,
            addingMapping,
            newMapping,
            newMappingInput,
            borrowerColumns,
            doneEditSection3,
            onMatchpointChange,
            saveMapping,
            confirmDeleteMapping,
            startAddMapping,
            saveNewMapping,
            cancelNewMapping,
            // Section 4
            domains,
            selectedDomain,
            domainEdit,
            domainEditKey,
            libraries,
            categories,
            libraryLabel,
            startEditSection4,
            doneEditSection4,
            selectDomain,
            addDomain,
            saveDomain,
            confirmDeleteDomain,
        };
    },
};
</script>
