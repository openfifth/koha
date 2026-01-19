<template>
    <li class="breadcrumb-item">
        <span>
            <a
                v-if="item.is_external && item.path && !item.disabled"
                :href="item.path"
            >
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span v-if="item.title">{{ $__(item.title) }}</span>
                <template v-if="item.is_external">
                    &nbsp;<i
                        class="fa fa-external-link"
                        aria-hidden="true"
                        style="font-size: 0.8em; opacity: 0.7"
                    ></i>
                </template>
            </a>
            <router-link
                v-else-if="item.name && !item.disabled"
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
                :class="{ disabled: item.disabled }"
            >
                <template v-if="item.icon">
                    <i :class="`${item.icon}`"></i>&nbsp;
                </template>
                <span class="" v-if="item.title">{{ $__(item.title) }}</span>
            </a>
        </span>
        <ul v-if="item.children && item.children.length">
            <NavigationItem
                v-for="(item, key) in item.children"
                :item="item"
            ></NavigationItem>
        </ul>
    </li>
</template>

<script>
export default {
    name: "NavigationItem",
    props: {
        item: Object,
        params: Object,
    },
};
</script>

<style></style>
