<template>
    <fieldset
        v-if="instancedResource.table.additionalFilters?.length > 0"
        class="filters"
    >
        <template v-if="instancedResource.getTableFilterFormElementsLabel()"
            >{{ instancedResource.getTableFilterFormElementsLabel()
            }}{{ " " }}</template
        >
        <template v-for="(filter, index) in wrappedFilters" v-bind:key="index">
            <FormElement :resource="filters" :attr="filter" :index="index" />
        </template>
        <input
            v-if="!instancedResource.table.hideFilterButton"
            @click="
                instancedResource.filterTable(
                    filters,
                    table,
                    instancedResource.embedded
                )
            "
            id="filterTable"
            type="button"
            :value="$__('Filter')"
        />
    </fieldset>
</template>

<script>
import { ref, computed, nextTick } from "vue";
import FormElement from "./FormElement.vue";
export default {
    components: { FormElement },
    props: {
        instancedResource: Object,
        table: Object,
    },
    setup(props) {
        const filters = ref(
            props.instancedResource.getFilterValues
                ? props.instancedResource.getFilterValues(
                      props.instancedResource.route.query
                  )
                : {}
        );

        const wrappedFilters = computed(() =>
            props.instancedResource.table.additionalFilters.map(filter =>
                filter.immediateFilter
                    ? {
                          ...filter,
                          onClick: resource => {
                              filter.onClick?.(resource);
                              nextTick(() =>
                                  props.instancedResource.filterTable(
                                      filters.value,
                                      props.table,
                                      props.instancedResource.embedded
                                  )
                              );
                          },
                      }
                    : filter
            )
        );

        return {
            filters,
            wrappedFilters,
        };
    },
};
</script>

<style scoped>
.filters > :deep(input[type="checkbox"]),
.filters > :deep(input[type="button"]) {
    margin-left: 1rem;
}
</style>
