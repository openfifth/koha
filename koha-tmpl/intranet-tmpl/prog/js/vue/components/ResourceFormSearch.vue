<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else :id="`${instancedResource.resourceNamePlural}_add`">
        <h2>{{ instancedResource.i18n.searchLabel }}</h2>
        <form
            @submit="
                instancedResource.handleResourceSearch($event, searchParams)
            "
        >
            <SplitScreenWrapper
                v-if="
                    instancedResource.searchGroupsDisplayMode == 'splitScreen'
                "
                :fieldList="instancedResource.getFieldGroupings('Search')"
                :splitScreenGroupings="
                    instancedResource.getSplitScreenGroupings('search')
                "
            >
                <template #splitPane="{ paneFieldList }">
                    <fieldset
                        style="margin-bottom: 0.9em"
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
                                <FormElement
                                    :resource="searchParams"
                                    :attr="attr"
                                    :index="index"
                                />
                            </li>
                        </ol>
                    </fieldset>
                </template>
            </SplitScreenWrapper>
            <div v-else>
                <fieldset
                    v-for="(
                        group, counter
                    ) in instancedResource.getFieldGroupings('Search')"
                    v-bind:key="counter"
                    class="rows"
                >
                    <legend v-if="group.name">{{ group.name }}</legend>
                    <ol>
                        <li
                            v-for="(attr, index) in group.fields"
                            v-bind:key="index"
                        >
                            <FormElement
                                :resource="searchParams"
                                :attr="attr"
                                :index="index"
                            />
                        </li>
                    </ol>
                </fieldset>
            </div>
            <fieldset class="action">
                <ButtonSubmit />
            </fieldset>
        </form>
    </div>
</template>

<script>
import { ref } from "vue";
import FormElement from "./FormElement.vue";
import ButtonSubmit from "./ButtonSubmit.vue";
import { $__ } from "@koha-vue/i18n";
import SplitScreenWrapper from "./SplitScreenWrapper.vue";

export default {
    inheritAttrs: false,
    setup(props) {
        const initialized = ref(true);
        const searchParams = ref(props.instancedResource.newResource);

        return {
            initialized,
            searchParams,
        };
    },
    props: {
        instancedResource: Object,
    },
    components: {
        ButtonSubmit,
        FormElement,
        SplitScreenWrapper,
    },
    name: "ResourceFormSearch",
};
</script>

<style scoped>
div.rows li {
    border-bottom: none;
}
div.rows + div.rows {
    margin-top: 0em;
}
.accordion fieldset legend {
    border: 1px solid #fff;
    margin-bottom: 0rem;
    margin-left: -0.5em;
    margin-top: -0.5em;
    padding: 0.7em;
}
.accordion fieldset legend.collapsed {
    margin-bottom: -0.5em;
}
.accordion fieldset legend:hover {
    border: 1px solid #6faf44;
    cursor: pointer;
}
.accordion fieldset legend i {
    color: #4c7aa8;
    font-size: 80%;
    padding-right: 0.2rem;
}
.accordion legend.collapsed i.fa.fa-caret-down::before {
    content: "\f0da";
}
.accordion fieldset.rows ol {
    padding: 0;
}
</style>
