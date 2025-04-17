<template>
    <div id="toolbar" class="btn-toolbar">
        <template v-if="toolbarButtons">
            <template
                :key="`toolbar-button-${i}`"
                v-for="(button, i) in toolbarButtons(
                    resource,
                    component,
                    i18n,
                    componentPropData
                )"
            >
                <ToolbarButton
                    :action="button.action"
                    @click="button.onClick"
                    :title="button.title"
                    :to="button.to"
                    :icon="button.icon"
                />
            </template>
        </template>
        <slot></slot>
    </div>
</template>

<script>
import ToolbarButton from "./ToolbarButton.vue";
export default {
    props: {
        toolbarButtons: Function,
        component: String,
        resource: Object,
        i18n: Object,
        componentPropData: Object,
    },
    components: { ToolbarButton },
    name: "Toolbar",
};
</script>
