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
        sysprefs: null,
        permittedUsers: null,
        libGroupFilter: "",
        navigationBlocked: false,
        currentPermission: null,
        moduleList: {
            funds: { name: "Funds and ledgers", code: "funds" },
        },
        permissionsMatrix: permissionsMatrix,
        currencies: [],
        gstValues: [],
        authorisedValues: {
            av_fund_type: "FUND_TYPE",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        formatValueWithCurrency(value, currency) {
            const formattedPrice = Number(value).format_price();
            if (!currency) {
                return formattedPrice;
            }
            const { symbol } = store.currencies.find(
                curr => curr.currency === currency
            );
            if (!value) {
                return `${symbol}0`;
            }
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
        getActiveCurrency: computed(() => {
            return store.currencies.find(curr => curr.active);
        }),
        getSystemCurrencyRate(currency) {
            return store.currencies.find(curr => curr.currency === currency)
                .rate;
        },
        getCurrencyConversionRate(currencyFrom, currencyTo) {
            if (currencyFrom === currencyTo) return 1.0;
            const activeCurrency = getters.getActiveCurrency;
            if (!currencyTo) currencyTo = activeCurrency.currency;
            if (!currencyFrom) currencyFrom = activeCurrency.currency;
            if (currencyFrom === activeCurrency.currency)
                return activeCurrency.rate;
            if (currencyTo === activeCurrency.currency)
                return getters.getSystemCurrencyRate(currencyFrom);

            const currencyFromRate =
                getters.getSystemCurrencyRate(currencyFrom);
            const currencyToRate = getters.getSystemCurrencyRate(currencyTo);
            return (currencyToRate * 100) / (currencyFromRate * 100);
        },
    };

    return {
        ...toRefs(store),
        ...actions,
        ...getters,
    };
});
