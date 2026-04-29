<template>
    <input
        @click="callback && callback()"
        :class="cssClass"
        type="button"
        :value="title"
        :id="idString"
    />
</template>

<script>
import { $__ } from "@koha-vue/i18n";
export default {
    name: "ButtonSubmit",
    props: {
        title: {
            type: String,
            default: $__("Submit"),
            required: false,
        },
        icon: {
            type: String,
            required: false,
        },
        cssClass: {
            type: String,
            default: "btn btn-primary",
            required: false,
        },
        callback: {
            type: Function,
        },
        idString: String | null,
    },
};
</script>
