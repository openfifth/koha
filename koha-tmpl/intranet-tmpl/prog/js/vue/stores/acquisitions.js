import { defineStore } from "pinia";
import { permissionsMatrix } from "../data/permissionsMatrix";
import { reactive, computed, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";
import { acquisitionsActions } from "../composables/acquisitions";
import { $__ } from "@koha-vue/i18n";

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
            av_acquisition_method: "ACQUISITION_METHOD",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        ...acquisitionsActions(store),
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
        getBranchnamesFromGroups(libraryGroups) {
            return libraryGroups.reduce(
                (acc, alg) => {
                    alg.libraries.forEach(lib => {
                        if (!acc.branchNames.includes(lib.branchname)) {
                            acc.branchNames.push(lib.branchname);
                        }
                    });
                    acc.groupNames.push(alg?.group?.title);
                    return acc;
                },
                { branchNames: [], groupNames: [] }
            );
        },
        applyNumberValidation() {
            return {
                formErrorHandler: value => {
                    return /^[\-]?\d*(\.\d{0,2})*$/.test(value);
                },
                formErrorMessage: $__(
                    "Please add amount in valid format: 0.00"
                ),
            };
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
        differentCurrenciesInLedgers: computed(() => {
            return store.sysprefs.different_currencies_in_ledgers === "1"
                ? true
                : false;
        }),
    };

    return {
        ...toRefs(store),
        ...actions,
        ...getters,
    };
});
