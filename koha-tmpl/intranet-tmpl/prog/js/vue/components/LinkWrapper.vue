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
        :href="linkData.href"
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

        if (props.linkData?.href && props.linkData.params) {
            props.linkData.href += "?";
            Object.keys(props.linkData.params).forEach(key => {
                const paramValue =
                    formattedParams.value[key] || props.linkData.params[key];
                props.linkData.href += `${key}=${paramValue}&`;
            });
            props.linkData.href = props.linkData.href.slice(0, -1);
        }
        if (props.linkData?.href && props.linkData.slug) {
            props.linkData.href += `/${props.resource[props.linkData.slug]}`;
        }
        return {
            formattedParams,
            paramsFound,
        };
    },
};
</script>

<style></style>
