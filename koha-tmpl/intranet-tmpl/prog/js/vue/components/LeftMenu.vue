<template>
    <aside>
        <div class="sidebar_menu">
            <h5>{{ $__(title) }}</h5>
            <ul>
                <NavigationItem
                    v-for="(item, key) in navigationTree"
                    v-bind:key="key"
                    :item="item"
                ></NavigationItem>
            </ul>
        </div>
    </aside>
</template>

<script>
import { inject } from "vue"
import NavigationItem from "./NavigationItem.vue"
export default {
    name: "LeftMenu",
    data() {
        return {
            navigationTree: this.leftNavigation,
        }
    },
    setup: () => {
        const navigationStore = inject("navigationStore")
        const { leftNavigation } = navigationStore
        return {
            leftNavigation,
        }
    },
    async beforeMount() {
        if (this.condition)
            this.navigationTree = await this.condition(this.navigationTree)
    },
    props: {
        title: String,
        condition: Function,
    },
    components: {
        NavigationItem,
    },
}
</script>

<style scoped>
/* This is declared here rather than backporting bug 37222 */
.sidebar_menu {
    background-color: #E6E6E6;
    display: block;
    padding: 1em 0 1em 0;

    h5 {
        color: #666;
        font-size: 1.3em;
        font-weight: bold;
        margin-top: 0;
        padding-left: .5em;
    }

    ul {
        margin-bottom: 10px;
        padding-left: 0;

        ul {
            background-color: #F3F4F4;

            li {
                a {
                    padding: .5em .3em .5em 1.3rem;
                }
            }
        }

        li {
            list-style: none;

            a {
                border-left: 5px solid transparent;
                color: #000;
                display: block;
                padding: .7em .3em .7em 1rem;
                text-decoration: none;
            }

            &.active > a,
            a:hover,
            a.current {
                background-color: #F3F4F4;
                border-left: solid 5px $background-color-primary;
                color: $green-text-color;
                font-weight: bold;
                text-decoration: none;
            }

            a:hover:not( .current ) {
                border-left: solid 5px $background-color-secondary;
                font-weight: normal;
            }

            &.active > a:hover {
                border-left: solid 5px $background-color-primary;
                font-weight: bold;
            }
        }
    }

    .breadcrumb-item {
        font-style: normal;
    }
}
.sidebar_menu a.router-link-active {
    font-weight: 700;
}
#menu ul ul,
.sidebar_menu ul ul {
    padding-left: 2em;
    font-size: 100%;
}

.sidebar_menu ul li a.disabled {
    color: #666;
    pointer-events: none;
    font-weight: 700;
}
.sidebar_menu ul li a.disabled.router-link-active {
    color: #000;
}
</style>
