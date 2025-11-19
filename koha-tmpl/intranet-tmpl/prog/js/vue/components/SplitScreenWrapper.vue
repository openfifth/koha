<template>
    <template v-for="pane in panesToDisplay" :key="pane.pane">
        <div
            v-if="pane.type === 'splitPane'"
            class="row"
            style="margin-bottom: 0.9em"
        >
            <div
                v-for="splitPane in pane.paneGroup"
                :key="splitPane.pane"
                :class="columnSizeClass(pane)"
            >
                <slot name="splitPane" :paneFieldList="splitPane.fields"></slot>
            </div>
        </div>
        <template v-else>
            <slot name="splitPane" :paneFieldList="pane.fields"></slot>
        </template>
    </template>
</template>

<script>
import { computed } from "vue";
export default {
    props: {
        fieldList: Array,
        splitScreenGroupings: Array,
    },
    setup(props) {
        const getPaneSortOrder = group => {
            return props.splitScreenGroupings.findIndex(
                grp => grp.name === group
            );
        };
        const determineGroupsForPane = paneGroups => {
            const groups = props.fieldList.filter(group =>
                paneGroups.includes(group.name)
            );
            return groups.sort(
                (a, b) => getPaneSortOrder(a.name) - getPaneSortOrder(b.name)
            );
        };
        const panesToDisplay = computed(() => {
            return props.splitScreenGroupings.reduce((acc, curr) => {
                if (curr.pane.toString().includes("break")) {
                    acc.push({
                        pane: curr.pane.toString(),
                        fields: determineGroupsForPane(curr.groups),
                    });
                    return acc;
                }
                if (
                    acc.length === 0 ||
                    acc[acc.length - 1]?.pane?.includes("break")
                ) {
                    acc.push({
                        type: "splitPane",
                        paneGroup: [
                            {
                                pane: curr.pane,
                                fields: determineGroupsForPane(curr.groups),
                            },
                        ],
                    });
                } else {
                    acc[acc.length - 1].paneGroup.push({
                        pane: curr.pane,
                        fields: determineGroupsForPane(curr.groups),
                    });
                }
                return acc;
            }, []);
        });
        const columnSizeClass = pane => {
            return `col-sm-${Math.floor(12 / pane.paneGroup.length)}`;
        };
        return {
            determineGroupsForPane,
            panesToDisplay,
            columnSizeClass,
        };
    },
};
</script>

<style></style>
