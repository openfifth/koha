<template>
    <li class="breadcrumb-item">
        <span>
            <router-link
                v-if="item.name && !item.disabled"
                :to="{ name: item.name, params }"
            >
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span v-if="item.title">{{ $__(item.title) }}</span>
            </router-link>
            <router-link
                v-else-if="item.path && !item.disabled"
                :to="item.path"
            >
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span v-if="item.title">{{ $__(item.title) }}</span>
            </router-link>
            <a v-else-if="item.href && !item.disabled" :href="item.href">
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span v-if="item.title">{{ $__(item.title) }}</span>
            </a>
            <a
                v-else
                href="#"
                aria-current="page"
                :class="{ disabled: item.disabled, collapsible: isCollapsible }"
                @click.prevent="toggleChildren"
            >
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span class="" v-if="item.title">{{ $__(item.title) }}</span>
                <i
                    v-if="isCollapsible"
                    :class="
                        isExpanded ? 'fa fa-caret-down' : 'fa fa-caret-right'
                    "
                    class="nav-collapse"
                ></i>
            </a>
        </span>
        <template v-if="hasChildren">
            <ul v-show="isExpanded">
                <NavigationItem
                    v-for="(item, key) in item.children"
                    :key="key"
                    :item="item"
                ></NavigationItem>
            </ul>
        </template>
    </li>
</template>

<script>
import { ref, computed } from "vue";

export default {
    name: "NavigationItem",
    props: {
        item: Object,
        params: Object,
    },
    setup(props) {
        const isExpanded = ref(!props.item.collapsible);

        const hasChildren = computed(
            () => !!(props.item.children && props.item.children.length)
        );

        const isCollapsible = computed(
            () => hasChildren.value && !!props.item.collapsible
        );

        const toggleChildren = () => {
            if (isCollapsible.value) isExpanded.value = !isExpanded.value;
        };

        return { isExpanded, hasChildren, isCollapsible, toggleChildren };
    },
};
</script>

<style scoped>
.nav-collapse {
    margin-left: 0.35em;
    font-size: 0.85em;
}
a.disabled.collapsible {
    pointer-events: auto;
    cursor: pointer;
}
</style>
