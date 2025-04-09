<template>
    <div id="toolbar" class="btn-toolbar">
        <template v-for="(button, i) in buttons">
            <ToolbarButton
                :action="button.action"
                @click="button.onClick"
                :title="button.title"
                :to="button.to"
                :icon="button.icon"
            />
        </template>
    </div>
</template>

<script>
import ToolbarButton from "./ToolbarButton.vue";
export default {
    props: {
        buttons: {
            type: Array,
        },
    },
    components: { ToolbarButton },
    name: "Toolbar",
};
</script>
