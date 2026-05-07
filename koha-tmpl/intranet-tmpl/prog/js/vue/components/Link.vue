<template>
    <ToolTip v-if="disabled" :toolTip="hint"
        ><a
            class="btn btn-default disabled"
            aria-disabled="true"
            style="pointer-events: none"
            ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</a
        ></ToolTip
    >
    <a v-else-if="isActionButton" @click="onClick" class="btn btn-default"
        ><font-awesome-icon :icon="buttonIcon" /> {{ title }}</a
    >
    <a
        v-else-if="action === undefined && onClick"
        @click="onClick"
        class="btn btn-default"
        ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</a
    >
    <a
        v-else-if="callback"
        @click="typeof callback === 'string' ? redirect() : callback(this)"
        :class="cssClass"
        style="cursor: pointer"
    >
        <font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}
    </a>
    <router-link v-else :to="to" :class="cssClass"
        ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</router-link
    >
</template>

<script>
import { computed } from "vue";
import ToolTip from "./ToolTip.vue";
export default {
    props: {
        action: {
            type: String,
            required: false,
        },
        to: {
            type: [String, Object],
            required: false,
        },
        icon: {
            type: String,
            required: false,
        },
        title: {
            type: String,
        },
        callback: {
            type: [String, Function],
            required: false,
        },
        cssClass: {
            type: String,
            default: "btn btn-default",
            required: false,
        },
        onClick: { type: Function, required: false },
        disabled: { type: Boolean, default: false },
        hint: { type: String, required: false },
    },
    setup(props) {
        const formatUrl = url => {
            if (url.includes("http://") || url.includes("https://")) return url;
            if (url.includes("cgi-bin/koha"))
                return `//${window.location.host}/${url}`;
            return `//${url}`;
        };
        const handleQuery = query => {
            let url = props.to.path;
            if (props.to.hasOwnProperty("query")) {
                url +=
                    "?" +
                    Object.keys(props.to.query)
                        .map(
                            queryParam =>
                                `${queryParam}=${props.to.query[queryParam]}`
                        )
                        .join("&");
            }
            return url;
        };
        const redirect = url => {
            const redirectParams = url ? url : props.to;
            window.location.href = formatUrl(
                typeof redirectParams === "object"
                    ? handleQuery(redirectParams)
                    : redirectParams
            );
        };
        const actionList = ["add", "delete", "edit", "search"];
        const iconList = {
            add: "plus",
            delete: "trash",
            edit: "pencil",
            search: "magnifying-glass",
        };
        const isActionButton = computed(() => {
            return actionList.includes(props.action);
        });
        const buttonIcon = computed(() => {
            return iconList[props.action];
        });
        return { redirect, handleQuery, formatUrl, isActionButton, buttonIcon };
    },
    components: { ToolTip },
    emits: ["go-to-add-resource", "delete-resource", "go-to-edit-resource"],
    name: "Link",
};
</script>
