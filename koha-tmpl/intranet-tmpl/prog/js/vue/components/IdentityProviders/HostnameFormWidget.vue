<template>
    <div class="row g-0 border rounded hostname-form-widget">
        <!-- Left: hostname list -->
        <div class="col-md-3 border-end bg-light">
            <div
                class="list-group list-group-flush"
                style="max-height: 360px; overflow-y: auto"
            >
                <button
                    v-for="(h, idx) in localList"
                    :key="idx"
                    type="button"
                    class="list-group-item list-group-item-action d-flex justify-content-between align-items-center py-2"
                    :class="{
                        active: selectedIndex === idx && !isAdding,
                    }"
                    @click="selectItem(idx)"
                >
                    <span class="text-truncate me-2 small">{{
                        h.hostname || $__("(unnamed)")
                    }}</span>
                    <span class="d-flex gap-1 flex-shrink-0">
                        <span v-if="h.is_enabled" class="badge bg-success">{{
                            $__("Active")
                        }}</span>
                        <span v-else class="badge bg-warning text-dark">{{
                            $__("Inactive")
                        }}</span>
                        <span
                            v-if="h.force_sso_opac"
                            class="badge bg-primary"
                            :title="$__('Force SSO: OPAC')"
                            >{{ $__("SSO OPAC") }}</span
                        >
                        <span
                            v-if="h.force_sso_staff"
                            class="badge bg-primary"
                            :title="$__('Force SSO: staff')"
                            >{{ $__("SSO Staff") }}</span
                        >
                    </span>
                </button>
                <div
                    v-if="localList.length === 0"
                    class="list-group-item text-muted small"
                >
                    {{ $__("No hostnames configured.") }}
                </div>
            </div>
            <div class="p-2 border-top">
                <button
                    type="button"
                    class="btn btn-sm btn-default w-100"
                    @click="startAdd"
                >
                    <i class="fa fa-plus"></i>
                    {{ $__("Add hostname") }}
                </button>
            </div>
        </div>

        <!-- Right: hostname configuration form -->
        <div class="col-md-9 p-3">
            <div
                v-if="selectedIndex === null && !isAdding"
                class="d-flex align-items-center justify-content-center h-100 text-muted"
                style="min-height: 200px"
            >
                {{ $__("Select a hostname to configure, or add a new one") }}
            </div>
            <template v-else>
                <h5 v-if="isAdding">{{ $__("New hostname") }}</h5>
                <h5 v-else>
                    {{ $__("Configure") }}:
                    <code>{{ editForm.hostname }}</code>
                </h5>

                <fieldset class="rows">
                    <ol>
                        <li v-if="isAdding">
                            <label class="required" for="hfw-hostname"
                                >{{ $__("Hostname") }}:</label
                            >
                            <input
                                id="hfw-hostname"
                                type="text"
                                class="form-control"
                                v-model="editForm.hostname"
                                placeholder="library.example.org"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="hfw-is-enabled">{{
                                $__("Active")
                            }}</label>
                            <div class="form-check form-switch">
                                <input
                                    id="hfw-is-enabled"
                                    class="form-check-input"
                                    type="checkbox"
                                    v-model="editForm.is_enabled"
                                    role="switch"
                                />
                            </div>
                        </li>
                        <li>
                            <label for="hfw-force-sso-opac">{{
                                $__("Force SSO (OPAC)")
                            }}</label>
                            <div class="form-check form-switch">
                                <input
                                    id="hfw-force-sso-opac"
                                    class="form-check-input"
                                    type="checkbox"
                                    v-model="editForm.force_sso_opac"
                                    role="switch"
                                />
                            </div>
                            <span class="text-muted">{{
                                $__(
                                    "Automatically redirect OPAC users on this hostname to this provider"
                                )
                            }}</span>
                        </li>
                        <li>
                            <label for="hfw-force-sso-staff">{{
                                $__("Force SSO (staff)")
                            }}</label>
                            <div class="form-check form-switch">
                                <input
                                    id="hfw-force-sso-staff"
                                    class="form-check-input"
                                    type="checkbox"
                                    v-model="editForm.force_sso_staff"
                                    role="switch"
                                />
                            </div>
                            <span class="text-muted">{{
                                $__(
                                    "Automatically redirect staff users on this hostname to this provider"
                                )
                            }}</span>
                        </li>
                    </ol>
                </fieldset>

                <div class="d-flex gap-2 mt-2">
                    <button
                        type="button"
                        class="btn btn-primary btn-sm"
                        :disabled="isAdding && !editForm.hostname?.trim()"
                        @click="saveItem"
                    >
                        {{ $__("Save") }}
                    </button>
                    <button
                        v-if="!isAdding"
                        type="button"
                        class="btn btn-danger btn-sm"
                        @click="removeItem"
                    >
                        <i class="fa fa-trash"></i>
                        {{ $__("Remove") }}
                    </button>
                    <button type="button" class="cancel" @click="cancelItem">
                        {{ $__("Cancel") }}
                    </button>
                </div>
            </template>
        </div>
    </div>
</template>

<script>
import { ref } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "HostnameFormWidget",
    props: {
        modelValue: {
            type: Array,
            default: () => [],
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const localList = ref([...(props.modelValue || [])]);
        const selectedIndex = ref(null);
        const isAdding = ref(false);
        const editForm = ref({});

        const selectItem = idx => {
            isAdding.value = false;
            selectedIndex.value = idx;
            editForm.value = { ...localList.value[idx] };
        };

        const startAdd = () => {
            selectedIndex.value = null;
            isAdding.value = true;
            editForm.value = {
                hostname: "",
                is_enabled: true,
                force_sso_opac: false,
                force_sso_staff: false,
            };
        };

        const saveItem = () => {
            if (isAdding.value) {
                if (!editForm.value.hostname?.trim()) return;
                const updated = [...localList.value, { ...editForm.value }];
                localList.value = updated;
                selectedIndex.value = updated.length - 1;
                isAdding.value = false;
            } else {
                const updated = [...localList.value];
                updated[selectedIndex.value] = { ...editForm.value };
                localList.value = updated;
            }
            emit("update:modelValue", [...localList.value]);
        };

        const removeItem = () => {
            const updated = localList.value.filter(
                (_, i) => i !== selectedIndex.value
            );
            localList.value = updated;
            selectedIndex.value = null;
            editForm.value = {};
            emit("update:modelValue", [...localList.value]);
        };

        const cancelItem = () => {
            if (isAdding.value) {
                isAdding.value = false;
            } else {
                selectedIndex.value = null;
            }
            editForm.value = {};
        };

        return {
            localList,
            selectedIndex,
            isAdding,
            editForm,
            selectItem,
            startAdd,
            saveItem,
            removeItem,
            cancelItem,
            $__,
        };
    },
};
</script>
