<template>
    <h2>{{ headerString }}</h2>
</template>

<script>
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        resourceCount: String,
    },
    setup(props) {
        const today = new Date().toString();
        const headerString = $__("%s Items overdue as of %s").format(
            props.resourceCount,
            $date(today)
        );
        return {
            headerString,
        };
    },
};
</script>

<style></style>
