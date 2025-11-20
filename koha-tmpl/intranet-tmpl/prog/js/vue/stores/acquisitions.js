import { defineStore } from "pinia";
import { permissionsMatrix } from "../data/permissionsMatrix";
import { reactive, computed, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";


export const useAcquisitionsStore = defineStore("acquisitionsStore", () => {
    const store = reactive({
        user: {
            loggedInUser: null,
            userflags: null,
        },
        settings: null,
        permittedUsers: null,
        libGroupFilter: "",
        navigationBlocked: false,
        currentPermission: null,
        moduleList: {
            funds: { name: "Funds and ledgers", code: "funds" },
        },
        permissionsMatrix: permissionsMatrix,
        currencies: [],
        authorisedValues: {
            av_fund_type: "FUND_TYPE",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        formatValueWithCurrency(value, currency) {
            const { symbol } = store.currencies.find(
                curr => curr.currency === currency
            );
            if (!value) {
                return `${symbol}0`;
            }
            const formattedPrice = value.format_price();
            if (!formattedPrice) {
                return `${symbol}0`;
            }
            if (formattedPrice < 0) {
                return `-${symbol}${-formattedPrice}`;
            }
            return `${symbol}${formattedPrice}`;
        },
    };
    const getters = {
        modulesEnabled: computed(() => {
            const modulesEnabled = store.settings.modulesEnabled;
            return modulesEnabled.value ? modulesEnabled.value : "";
        }),
    };

    return {
        ...toRefs(store),
        ...actions,
        ...getters,
    };
});
