<template>
    <div class="page-section">
        <div class="d-flex justify-content-between align-items-center mb-2">
            <h2>
                <i v-if="group.icon" :class="group.icon"></i>
                {{ group.name }}
            </h2>
            <button
                v-if="!editing && !disabled"
                type="button"
                class="btn btn-default"
                :aria-label="$__('Edit %s').format(group.name)"
                @click="startEdit"
            >
                <i class="fa fa-pencil"></i>
                {{ $__("Edit") }}
            </button>
            <span v-if="disabled" class="text-muted" role="status">{{
                $__("Save basic settings first")
            }}</span>
        </div>

        <!-- VIEW MODE -->
        <template v-if="!editing || disabled">
            <fieldset class="rows">
                <ol>
                    <li v-for="attr in group.fields" :key="attr.name">
                        <ShowElement
                            :resource="resource"
                            :attr="attr"
                            :instancedResource="instancedResource"
                        />
                    </li>
                </ol>
            </fieldset>
        </template>

        <!-- EDIT MODE -->
        <template v-else>
            <fieldset class="rows">
                <ol>
                    <li v-for="(attr, index) in group.fields" :key="index">
                        <FormElement
                            :resource="localResource"
                            :attr="attr"
                            :index="index"
                        />
                    </li>
                </ol>
            </fieldset>

            <fieldset class="action">
                <button
                    type="button"
                    class="btn btn-primary"
                    @click="saveSection"
                >
                    <i class="fa fa-save"></i>
                    {{ $__("Save") }}
                </button>
                <button type="button" class="cancel" @click="cancelEdit">
                    {{ $__("Cancel") }}
                </button>
            </fieldset>
        </template>
    </div>
</template>

<script>
import { ref, watch, toRaw } from "vue";
import { $__ } from "@koha-vue/i18n";
import FormElement from "@koha-vue/components/FormElement.vue";
import ShowElement from "@koha-vue/components/ShowElement.vue"; // New Import

export default {
    name: "FormSection",
    components: {
        FormElement,
        ShowElement, // New Component
    },
    props: {
        group: {
            type: Object,
            required: true,
            // Example structure: { name: 'Section Title', icon: 'fa fa-info', fields: [...] }
        },
        resource: {
            type: Object,
            required: true,
        },
        instancedResource: {
            // New Prop
            type: Object,
            required: true,
        },
        startEditing: {
            type: Boolean,
            default: false,
        },
        disabled: {
            type: Boolean,
            default: false,
        },
    },
    emits: ["save", "cancel"],
    setup(props, { emit }) {
        const editing = ref(props.startEditing);
        const localResource = ref({});

        // Initialize localResource when the component is created or resource prop changes
        watch(
            () => props.resource,
            newResource => {
                localResource.value = { ...toRaw(newResource) };
            },
            { immediate: true }
        );

        const startEdit = () => {
            localResource.value = { ...toRaw(props.resource) }; // Copy original for cancellation
            editing.value = true;
        };

        const cancelEdit = () => {
            editing.value = false;
            // localResource is automatically reverted to original via watch effect on props.resource
        };

        const saveSection = () => {
            emit("save", props.group.name, localResource.value);
            editing.value = false;
        };

        return {
            editing,
            localResource,
            startEdit,
            cancelEdit,
            saveSection,
            $__,
        };
    },
};
</script>

<style scoped>
/* Add any scoped styles here if necessary, similar to ProviderWorkspace.vue */
</style>
