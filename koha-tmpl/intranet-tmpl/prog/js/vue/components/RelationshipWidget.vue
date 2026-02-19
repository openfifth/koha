<template>
    <fieldset
        v-if="displayMode !== 'table'"
        class="rows"
        :id="`${name + '_' + 'relationship'}`"
    >
        <legend v-if="title">{{ title }}</legend>
        <fieldset
            :id="`${name + '_' + counter}`"
            class="rows"
            v-for="(resourceRelationship, counter) in resourceRelationships"
            v-bind:key="counter"
        >
            <legend>
                {{ relationshipI18n.nameUpperCase + " " + (counter + 1) }}
                <a href="#" @click.prevent="deleteResourceRelationship(counter)"
                    ><i class="fa fa-trash"></i>
                    {{ relationshipI18n.removeThisMessage }}</a
                >
            </legend>
            <ol>
                <li
                    v-for="(attr, index) in relationshipFields"
                    v-bind:key="index"
                >
                    <FormElement
                        :resource="resourceRelationship"
                        :attr="attr"
                        :index="counter"
                        v-bind="handleOptions()"
                    />
                </li>
            </ol>
        </fieldset>
        <a
            v-if="resourceRelationshipCount > 0 || noCountRequired"
            class="btn btn-default add-new-relationship"
            @click="addResourceRelationship"
            ><font-awesome-icon icon="plus" />
            {{ relationshipI18n.addNewMessage }}</a
        >
        <span v-else-if="resourceRelationshipCount == 0">
            {{ relationshipI18n.noneCreatedYetMessage }}
        </span>
    </fieldset>
    <div v-else>
        <table class="table table-bordered table-sm">
            <thead class="table-light">
                <tr>
                    <th v-for="field in relationshipFields" :key="field.name">
                        {{ field.label }}
                    </th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                <tr
                    v-for="(item, counter) in resourceRelationships"
                    :key="counter"
                >
                    <td v-for="field in relationshipFields" :key="field.name">
                        <FormElement
                            :resource="item"
                            :attr="field"
                            :index="counter"
                        />
                    </td>
                    <td class="text-center">
                        <button
                            type="button"
                            class="btn btn-danger btn-sm"
                            @click="deleteResourceRelationship(counter)"
                        >
                            <i class="fa fa-trash"></i>
                        </button>
                    </td>
                </tr>
                <tr
                    v-if="
                        !resourceRelationships ||
                        resourceRelationships.length === 0
                    "
                >
                    <td
                        :colspan="relationshipFields.length + 1"
                        class="text-muted text-center"
                    >
                        {{ relationshipI18n.noneCreatedYetMessage }}
                    </td>
                </tr>
            </tbody>
        </table>
        <button
            type="button"
            class="btn btn-default btn-sm mt-2"
            @click="addResourceRelationship"
        >
            <i class="fa fa-plus"></i> {{ relationshipI18n.addNewMessage }}
        </button>
    </div>
</template>

<script>
import { onBeforeMount, provide, ref } from "vue";
import FormElement from "./FormElement.vue";

export default {
    name: "RelationshipWidget",
    setup(props) {
        const initialized = ref(false);
        const noCountRequired = ref(false);
        const resourceRelationshipCount = ref(null);
        const options = ref(null);

        provide("resourceRelationships", props.resourceRelationships);

        const addResourceRelationship = () => {
            if (!props.resourceRelationships) return;
            props.resourceRelationships.push({
                ...props.newRelationshipDefaultAttrs,
            });
        };
        const deleteResourceRelationship = counter => {
            if (!props.resourceRelationships) return;
            props.resourceRelationships.splice(counter, 1);
        };
        const getSelectOptions = filters => {
            const searchFilters = filters ? filters : {};
            props.apiClient.getAll(searchFilters).then(response => {
                options.value = response;
                resourceRelationshipCount.value = response.length;
                initialized.value = true;
            });
        };
        const handleOptions = () => {
            if (!options.value) return {};
            return { options: options.value };
        };

        onBeforeMount(() => {
            if (props.apiClient) {
                props.apiClient.count().then(
                    count => {
                        if (props.fetchOptions) {
                            getSelectOptions(props.filters);
                        } else {
                            resourceRelationshipCount.value = count;
                            initialized.value = true;
                        }
                    },
                    error => {}
                );
            } else {
                noCountRequired.value = true;
                initialized.value = true;
            }
        });
        return {
            noCountRequired,
            resourceRelationshipCount,
            options,
            addResourceRelationship,
            deleteResourceRelationship,
            handleOptions,
            initialized,
        };
    },
    props: {
        resourceRelationships: Array,
        relationshipFields: Array,
        relationshipI18n: Object,
        title: String,
        apiClient: Object,
        newRelationshipDefaultAttrs: Object,
        filters: Object,
        fetchOptions: Boolean,
        name: String,
        displayMode: {
            type: String,
            default: "stacked",
        },
    },
    components: {
        FormElement,
    },
};
</script>

<style scoped>
.add-new-relationship {
    margin-top: 0.5em;
}
</style>
