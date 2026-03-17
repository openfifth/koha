<template>
    <a href="#" class="clear_attribute" @click="clearField($event)">
        <i class="fa fa-fw fa-trash-can"></i>
        {{ $__("Clear") }}
    </a>
</template>

<script>
export default {
    props: {
        resource: Object,
        propertyToClear: {
            type: String,
            default: "value",
        },
        arrayToDeleteFrom: {
            type: Array,
            default: null,
        },
        itemIndex: {
            type: Number,
            default: null,
        },
    },
    setup(props) {
        const clearField = event => {
            event.preventDefault();
            if (props.arrayToDeleteFrom !== null && props.itemIndex !== null) {
                props.arrayToDeleteFrom.splice(props.itemIndex, 1);
            } else {
                props.resource[props.propertyToClear] = "";
            }
        };
        return {
            clearField,
        };
    },
};
</script>

<style></style>
