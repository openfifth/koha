<template>
    <a v-if="action === 'add'" class="btn btn-default"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a v-else-if="action === 'delete'" class="btn btn-default"
        ><font-awesome-icon icon="trash" /> {{ title }}</a
    >
    <a v-else-if="action === 'edit'" class="btn btn-default"
        ><font-awesome-icon icon="pencil" /> {{ title }}</a
    >
    <router-link
        v-else-if="action === undefined && to"
        :to="to"
        class="btn btn-default"
        ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</router-link
    >
    <span v-else>{{ $__("Unknown action %s").format(action) }}</span>
</template>

<script>
export default {
    props: {
        action: {
            type: String,
        },
        to: {
            type: [String, Object],
        },
        icon: {
            type: String,
            required: false,
        },
        title: {
            type: String,
        },
    },
    name: "Toolbar",
};
</script>
