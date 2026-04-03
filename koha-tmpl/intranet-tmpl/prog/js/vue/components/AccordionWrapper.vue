<template>
    <div
        v-for="(group, counter) in accordionList"
        v-bind:key="counter"
        class="accordion"
        :class="{ 'group-placeholder-accordion': group.placeholder }"
    >
        <fieldset class="accordion-item">
            <legend
                v-if="group.name"
                type="button"
                data-bs-toggle="collapse"
                :data-bs-target="`#collapse-${counter}`"
                aria-expanded="true"
                :aria-controls="`collapse-${counter}`"
            >
                <i class="fa fa-caret-down" title="Collapse this section"></i>
                {{ group.name }}
            </legend>
            <div
                :id="`collapse-${counter}`"
                class="accordion-collapse collapse show"
                :aria-labelledby="`heading-${counter}`"
                data-bs-parent="#formAccordion"
            >
                <div v-if="group.placeholder" class="placeholder-content">
                    <p v-if="group.placeholder.description" class="mb-0">
                        {{ group.placeholder.description }}
                    </p>
                </div>
                <fieldset v-else class="accordion-body rows">
                    <slot name="accordionContent" :accordionGroup="group" />
                </fieldset>
            </div>
        </fieldset>
    </div>
</template>

<script>
export default {
    props: {
        accordionList: {
            type: Array,
            required: true,
        },
    },
};
</script>

<style>
.group-placeholder-accordion > fieldset {
    background-color: var(--bs-info-bg-subtle);
    border-radius: 4px;
}
.group-placeholder-accordion .placeholder-content {
    color: #6c757d;
    font-style: italic;
    padding: 0.75rem 1rem;
}
</style>
