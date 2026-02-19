<template>
    <fieldset class="rows" :id="`${name}_splitlist`">
        <div class="row g-0 border rounded">
            <!-- Left: item list -->
            <div class="col-md-3 border-end bg-light">
                <div
                    class="list-group list-group-flush"
                    style="max-height: 360px; overflow-y: auto"
                >
                    <button
                        v-for="(item, idx) in resourceRelationships"
                        :key="idx"
                        type="button"
                        class="list-group-item list-group-item-action d-flex justify-content-between align-items-center py-2"
                        :class="{ active: selectedIndex === idx }"
                        @click="selectItem(idx)"
                    >
                        <span class="text-truncate me-2 small">
                            {{ getItemTitle(item) || $__("(unnamed)") }}
                            <span
                                v-if="dirtyFlags[idx]"
                                class="text-warning ms-1"
                                :title="$__('Unsaved changes')"
                                >&#x25CF;</span
                            >
                        </span>
                        <span class="d-flex gap-1 flex-shrink-0">
                            <template
                                v-for="field in badgeFields"
                                :key="field.name"
                            >
                                <template v-if="field.badgeValues">
                                    <span
                                        v-for="bv in field.badgeValues.filter(
                                            bv => bv.value === item[field.name]
                                        )"
                                        :key="bv.value"
                                        class="badge"
                                        :class="bv.class || 'bg-secondary'"
                                        >{{ bv.label }}</span
                                    >
                                </template>
                                <template v-else>
                                    <span
                                        v-if="
                                            item[field.name] &&
                                            field.badgeTrueLabel
                                        "
                                        class="badge"
                                        :class="
                                            field.badgeTrueClass ||
                                            'bg-secondary'
                                        "
                                        >{{ field.badgeTrueLabel }}</span
                                    >
                                    <span
                                        v-else-if="
                                            !item[field.name] &&
                                            field.badgeFalseLabel
                                        "
                                        class="badge"
                                        :class="
                                            field.badgeFalseClass ||
                                            'bg-secondary'
                                        "
                                        >{{ field.badgeFalseLabel }}</span
                                    >
                                </template>
                            </template>
                        </span>
                    </button>
                    <div
                        v-if="resourceRelationships.length === 0"
                        class="list-group-item text-muted small"
                    >
                        {{ relationshipI18n.noneCreatedYetMessage }}
                    </div>
                </div>
                <div class="p-2 border-top">
                    <button
                        type="button"
                        class="btn btn-sm btn-default w-100"
                        @click="addItem"
                    >
                        <i class="fa fa-plus"></i>
                        {{ relationshipI18n.addNewMessage }}
                    </button>
                </div>
            </div>

            <!-- Right: item configuration form -->
            <div class="col-md-9 p-3">
                <div
                    v-if="selectedIndex === null"
                    class="d-flex align-items-center justify-content-center h-100 text-muted"
                    style="min-height: 200px"
                >
                    {{ $__("Select an item to configure, or add a new one") }}
                </div>
                <template v-else>
                    <!-- Info section: rendered by parent via default slot when needed -->
                    <slot :item="selectedItem"></slot>

                    <fieldset class="rows">
                        <ol>
                            <li
                                v-for="(field, fieldIdx) in relationshipFields"
                                :key="fieldIdx"
                            >
                                <FormElement
                                    :resource="selectedItem"
                                    :attr="field"
                                    :index="selectedIndex"
                                />
                            </li>
                        </ol>
                    </fieldset>

                    <a href="#" @click.prevent="removeItem">
                        <i class="fa fa-trash"></i>
                        {{ relationshipI18n.removeThisMessage }}
                    </a>
                </template>
            </div>
        </div>
    </fieldset>
</template>

<script>
import { ref, computed, watch, onMounted, provide } from "vue";
import { $__ } from "@koha-vue/i18n";
import FormElement from "@koha-vue/components/FormElement.vue";

export default {
    name: "SplitListWidget",
    components: { FormElement },
    props: {
        resourceRelationships: {
            type: Array,
            default: () => [],
        },
        relationshipI18n: {
            type: Object,
            required: true,
        },
        newRelationshipDefaultAttrs: {
            type: Object,
            default: () => ({}),
        },
        relationshipFields: {
            type: Array,
            default: () => [],
        },
        name: String,
        title: String,
        // Optional API client whose getAll(filters) populates the left list on
        // mount.  Pass this instead of pre-populating resourceRelationships in
        // the parent; the widget fetches and owns that initial load.
        apiClient: {
            type: Object,
            default: null,
        },
        // Query params forwarded verbatim to apiClient.getAll().  Resolved by
        // base-element.js getComponentProps() before reaching this component.
        filters: {
            type: Object,
            default: null,
        },
        // Optional mapping function applied to each item returned by
        // apiClient.getAll() before it is pushed into resourceRelationships.
        // Use this to reshape API response objects into the form data model
        // (e.g. converting is_enabled → mode).  Defaults to identity.
        transformItem: {
            type: Function,
            default: null,
        },
    },
    setup(props) {
        // Expose the relationships array to any deeply-nested component that
        // needs to read or mutate siblings (e.g. VendorContacts radio logic).
        provide("resourceRelationships", props.resourceRelationships);

        const selectedIndex = ref(null);

        // Parallel array tracking which items have been modified in this session.
        // Kept in sync with resourceRelationships via addItem / removeItem.
        const dirtyFlags = ref([]);

        onMounted(async () => {
            if (props.apiClient) {
                // Fetch list items from the API, transform them to the form's
                // data model, then push into the shared reactive array so the
                // parent's bound state reflects them automatically.
                const items = await props.apiClient.getAll(
                    props.filters || undefined
                );
                const transform = props.transformItem || (item => item);
                (items || [])
                    .map(transform)
                    .forEach(item => props.resourceRelationships.push(item));
            }
            dirtyFlags.value = (props.resourceRelationships || []).map(
                () => false
            );
        });

        const selectedItem = computed(() => {
            if (selectedIndex.value === null) return null;
            return props.resourceRelationships[selectedIndex.value];
        });

        // First required text field drives the left-panel title display.
        const titleField = computed(
            () =>
                props.relationshipFields.find(
                    f => f.required && f.type === "text"
                ) || props.relationshipFields.find(f => f.type === "text")
        );

        // Boolean fields that carry badge config are shown as status badges.
        const badgeFields = computed(() =>
            props.relationshipFields.filter(
                f =>
                    (f.type === "boolean" &&
                        (f.badgeTrueLabel || f.badgeFalseLabel)) ||
                    f.badgeValues?.length > 0
            )
        );

        const getItemTitle = item =>
            titleField.value ? item[titleField.value.name] || "" : "";

        // When selectedIndex changes, snapshot the item so we can detect edits.
        let selectionSnapshot = null;
        watch(selectedIndex, newIdx => {
            selectionSnapshot =
                newIdx !== null
                    ? JSON.stringify(props.resourceRelationships[newIdx])
                    : null;
        });

        // Deep-watch the selected item; mark dirty when it diverges from snapshot.
        watch(
            selectedItem,
            newVal => {
                if (
                    selectedIndex.value !== null &&
                    selectionSnapshot !== null &&
                    newVal &&
                    JSON.stringify(newVal) !== selectionSnapshot
                ) {
                    dirtyFlags.value[selectedIndex.value] = true;
                }
            },
            { deep: true }
        );

        const selectItem = idx => {
            selectedIndex.value = idx;
        };

        const addItem = () => {
            props.resourceRelationships.push({
                ...props.newRelationshipDefaultAttrs,
            });
            dirtyFlags.value.push(true);
            selectedIndex.value = props.resourceRelationships.length - 1;
        };

        const removeItem = () => {
            props.resourceRelationships.splice(selectedIndex.value, 1);
            dirtyFlags.value.splice(selectedIndex.value, 1);
            selectedIndex.value = null;
        };

        return {
            selectedIndex,
            selectedItem,
            dirtyFlags,
            badgeFields,
            getItemTitle,
            selectItem,
            addItem,
            removeItem,
            $__,
        };
    },
};
</script>
