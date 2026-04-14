<template>
    <router-link
        v-if="linkData && linkData.name && paramsFound"
        :to="{
            name: linkData.name,
            params: formattedParams,
        }"
    >
        <slot />
    </router-link>
    <a
        v-else-if="linkData && linkData.href"
        :href="builtHref"
        :class="{ disabled: linkData.disabled }"
    >
        <slot />
    </a>
    <slot v-else />
</template>

<script>
import { ref } from "vue";
export default {
    props: {
        linkData: Object,
        resource: Object,
    },
    setup(props) {
        const formattedParams = ref({});
        const paramsFound = ref(true);

        if (props.linkData && props.linkData.params) {
            Object.keys(props.linkData.params).forEach(key => {
                formattedParams.value[key] =
                    props.resource[props.linkData.params[key]];
                if (!formattedParams.value[key]) paramsFound.value = false;
            });
        }

        let builtHref = props.linkData?.href ?? null;
        if (builtHref && props.linkData.params) {
            builtHref += "?";
            Object.keys(props.linkData.params).forEach(key => {
                const paramValue =
                    formattedParams.value[key] || props.linkData.params[key];
                builtHref += `${key}=${paramValue}&`;
            });
            builtHref = builtHref.slice(0, -1);
        }
        if (builtHref && props.linkData.slug) {
            builtHref += `/${props.resource[props.linkData.slug]}`;
        }
        if (builtHref && props.linkData.fragment) {
            const fragment =
                typeof props.linkData.fragment === "function"
                    ? props.linkData.fragment(props.resource)
                    : props.linkData.fragment;
            builtHref += `#${fragment}`;
        }
        return {
            formattedParams,
            paramsFound,
            builtHref,
        };
    },
};
</script>

<style></style>
