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
            av_non_bibliographic_material_type:
                "NON_BIBLIOGRAPHIC_MATERIAL_TYPE",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        ...acquisitionsActions(store),
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
        applyNumberValidation({ positiveOnly = true } = {}) {
            return {
                formErrorHandler: value => {
                    const pattern = positiveOnly
                        ? /^\d*(\.\d{0,2})*$/
                        : /^[\-]?\d*(\.\d{0,2})*$/;
                    return (
                        pattern.test(value) &&
                        (!positiveOnly || Number(value) >= 0)
                    );
                },
                formErrorMessage: positiveOnly
                    ? $__(
                          "Please enter a positive amount in valid format: 0.00"
                      )
                    : $__("Please add amount in valid format: 0.00"),
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
