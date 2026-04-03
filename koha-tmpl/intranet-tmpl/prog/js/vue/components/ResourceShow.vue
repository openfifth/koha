<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else :id="`${instancedResource.resourceNamePlural}_show`">
        <slot
            name="toolbar"
            :resource="resource"
            :componentPropData="{ ...$props, ...$data }"
        />
        <h2 v-if="isNewResource">{{ instancedResource.i18n.newLabel }}</h2>
        <h2 v-else>
            {{
                instancedResource.i18n.displayName +
                " #" +
                resource[instancedResource.idAttr]
            }}
        </h2>
        <TabsWrapper v-if="displayMode == 'tabs'" :tabList="fieldList">
            <template #tabContent="{ tabGroup }">
                <fieldset class="rows">
                    <legend v-if="tabGroup.name">{{ tabGroup.name }}</legend>
                    <ol>
                        <li
                            v-for="(attr, index) in tabGroup.fields"
                            v-bind:key="index"
                        >
                            <ShowElement
                                :resource="resource"
                                :attr="attr"
                                :instancedResource="instancedResource"
                            />
                        </li>
                    </ol>
                </fieldset>
            </template>
        </TabsWrapper>
        <AccordionWrapper
            v-else-if="displayMode == 'accordion'"
            :accordionList="fieldList"
        >
            <template #accordionContent="{ accordionGroup }">
                <ol>
                    <li
                        v-for="(attr, index) in accordionGroup.fields"
                        v-bind:key="index"
                    >
                        <ShowElement
                            :resource="resource"
                            :attr="attr"
                            :instancedResource="instancedResource"
                        />
                    </li>
                </ol>
            </template>
        </AccordionWrapper>
        <SplitScreenWrapper
            v-else-if="displayMode == 'splitScreen'"
            :fieldList="fieldList"
            :splitScreenGroupings="instancedResource.splitScreenGroupings"
        >
            <template #splitPane="{ paneFieldList }">
                <fieldset
                    class="rows"
                    v-for="(group, counter) in paneFieldList"
                    v-bind:key="counter"
                >
                    <legend v-if="group.name">{{ group.name }}</legend>
                    <ol>
                        <li
                            v-for="(attr, index) in group.fields"
                            v-bind:key="index"
                        >
                            <ShowElement
                                :resource="resource"
                                :attr="attr"
                                :instancedResource="instancedResource"
                            />
                        </li>
                    </ol>
                </fieldset>
            </template>
        </SplitScreenWrapper>
        <div v-else-if="displayMode == 'sections'">
            <FormSection
                v-for="(group, counter) in fieldList"
                v-bind:key="counter"
                :group="group"
                :resource="resource"
                :instancedResource="instancedResource"
                :startEditing="isNewResource"
                :disabled="
                    group.requiresId &&
                    isNewResource &&
                    !resource[instancedResource.idAttr]
                "
                @save="
                    (groupName, updatedResource) =>
                        handleSectionSave(groupName, updatedResource)
                "
            />
        </div>
        <div v-else>
            <fieldset
                class="rows"
                v-for="(group, counter) in fieldList"
                v-bind:key="counter"
            >
                <legend v-if="group.name">{{ group.name }}</legend>
                <ol>
                    <li
                        v-for="(attr, index) in group.fields"
                        v-bind:key="index"
                    >
                        <ShowElement
                            :resource="resource"
                            :attr="attr"
                            :instancedResource="instancedResource"
                        />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <router-link
                    :to="{ name: instancedResource.components.list }"
                    role="button"
                    class="cancel"
                    >{{ $__("Close") }}</router-link
                >
            </fieldset>
        </div>
    </div>
</template>

<script>
import Toolbar from "./Toolbar.vue";
import ShowElement from "./ShowElement.vue";
import FormSection from "./FormSection.vue";
import { computed, onBeforeMount, ref } from "vue";
import TabsWrapper from "./TabsWrapper.vue";
import AccordionWrapper from "./AccordionWrapper.vue";
import SplitScreenWrapper from "./SplitScreenWrapper.vue";

export default {
    inheritAttrs: false,
    setup(props) {
        const initialized = ref(false);
        const resource = ref(null);
        const additionalProps = ref({});

        const isNewResource = computed(
            () =>
                !props.instancedResource.route.params[
                    props.instancedResource.idAttr
                ]
        );

        onBeforeMount(() => {
            if (isNewResource.value) {
                resource.value = {};
                initialized.value = true;
            } else {
                props.instancedResource.getResource(
                    props.instancedResource.route.params[
                        props.instancedResource.idAttr
                    ],
                    {
                        resource,
                        initialized,
                        instancedResource: props.instancedResource,
                        additionalProps,
                    },
                    "show"
                );
            }
        });

        const handleSectionSave = async (groupName, updatedResource) => {
            try {
                const result = await props.instancedResource.onShowSectionSave(
                    groupName,
                    updatedResource,
                    resource.value,
                    isNewResource.value
                );
                if (result) {
                    Object.assign(resource.value, result);
                    const newId = result[props.instancedResource.idAttr];
                    if (isNewResource.value && newId) {
                        props.instancedResource.router.push({
                            name: props.instancedResource.components.show,
                            params: {
                                [props.instancedResource.idAttr]: newId,
                            },
                        });
                    }
                }
            } catch (error) {
                // errors are surfaced by the httpClient / setError
            }
        };

        const fieldList = computed(() => {
            const fieldGroupings = props.instancedResource.getFieldGroupings(
                "Show",
                // Pass null for new resources so the hasDataToDisplay filter is skipped
                isNewResource.value ? null : resource.value
            );
            const fieldsToAppend = props.instancedResource
                .appendToShow({
                    ...props,
                    resource: resource.value,
                    additionalProps: additionalProps.value,
                })
                ?.filter(
                    field =>
                        !field.hidden ||
                        (field.hidden && field.hidden(resource.value))
                )
                .map(field => {
                    return {
                        name: field.name,
                        fields: [field],
                        ...(props.instancedResource.showGroupsDisplayMode ===
                        "splitScreen"
                            ? { splitPane: field.splitPane }
                            : {}),
                    };
                });

            return [
                ...fieldGroupings,
                ...(fieldsToAppend ? fieldsToAppend : []),
            ];
        });

        const displayMode = computed(() => {
            return props.instancedResource.showGroupsDisplayMode
                ? props.instancedResource.showGroupsDisplayMode
                : props.instancedResource.formGroupsDisplayMode || "";
        });

        return {
            initialized,
            resource,
            additionalProps,
            fieldList,
            displayMode,
            isNewResource,
            handleSectionSave,
        };
    },
    props: {
        instancedResource: Object,
    },
    components: {
        Toolbar,
        ShowElement,
        FormSection,
        TabsWrapper,
        AccordionWrapper,
        SplitScreenWrapper,
    },
    name: "ResourceShow",
};
</script>
