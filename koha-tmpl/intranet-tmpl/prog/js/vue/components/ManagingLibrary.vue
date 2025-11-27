<template>
    <template v-if="routeAction !== 'show'">
        <FormRelationshipSelect
            v-bind="$props"
            :onSelected="setGroupAccessValue"
        />
    </template>
    <template v-else>
        <LinkWrapper :linkData="linkData" :resource="resource">
            {{ formatValue({ value: "managing_library.name" }, resource) }}
        </LinkWrapper>
    </template>
    <li>
        <label>{{ $__("Group access") }}: </label>
        <span>{{ groupAccessList }}</span>
    </li>
</template>

<script>
import FormRelationshipSelect from "./FormRelationshipSelect.vue";
import LinkWrapper from "./LinkWrapper.vue";
import { useBaseElement } from "../composables/base-element.js";
import { computed, ref } from "vue";

export default {
    components: { FormRelationshipSelect, LinkWrapper },
    inheritAttrs: false,
    props: {
        relationshipOptionLabelAttr: String | null,
        relationshipAPIClient: Object | null,
        resource: Object | null,
        name: String | null,
        allowMultipleChoices: Boolean | null,
        relationshipRequiredKey: String | null,
        disabled: Boolean | false,
        required: Boolean | false,
        onSelected: Function | null,
        query: {
            type: Object,
            default: {},
        },
        routeAction: String,
        linkData: Object,
    },
    setup(props) {
        const baseElement = useBaseElement({ ...props });

        const groupAccess = ref(
            props.resource?.managing_library?.acquisitions_library_groups
        );
        const groupAccessList = computed(() => {
            return groupAccess.value.map(alg => alg.name).join(", ");
        });

        const setGroupAccessValue = (e, options, resource) => {
            const branchSelected = options.find(
                branch => branch.library_id === e
            );
            const acqLibraryGroups =
                branchSelected?.acquisitions_library_groups;
            groupAccess.value = acqLibraryGroups;
        };

        return {
            ...baseElement,
            groupAccess,
            groupAccessList,
            setGroupAccessValue,
        };
    },
};
</script>

<style></style>
