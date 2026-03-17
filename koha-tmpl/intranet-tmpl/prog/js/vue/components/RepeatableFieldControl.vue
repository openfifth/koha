<template>
    <a href="#" class="clone_attribute" @click="cloneField($event)">
        <i class="fa fa-fw fa-plus"></i>
        {{ $__("New") }}
    </a>
</template>

<script>
export default {
    props: {
        fieldLabel: String,
        fieldValues: Array,
        fieldName: String,
        currentValue: {
            type: Object,
            default(propValues) {
                if (typeof propValues.currentValue === "string")
                    return { [propValues.fieldName]: propValues.currentValue };
                return propValues.currentValue;
            },
        },
    },
    setup(props) {
        const cloneField = event => {
            event.preventDefault();
            props.fieldValues.push({
                [props.fieldName]: props.currentValue[props.fieldName],
                label: props.fieldLabel,
            });
        };
        return {
            cloneField,
        };
    },
};
</script>

<style></style>
