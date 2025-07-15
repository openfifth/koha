<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_allocation_add">
        <h2 v-if="fund_allocation.fund_allocation_id">
            {{
                $__("Edit fund allocation %s").format(
                    fund_allocation.fund_allocation_id
                )
            }}
        </h2>
        <h2 v-else>{{ $__("New fund allocation") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <h3>{{ $__("Allocate to fund") }}: {{ selectedFund.name }}</h3>
                <fieldset class="rows">
                    <ol>
                        <!-- <li>
                            <label for="fund_allocation_fund_id" class="required"
                                >Fund:</label
                            >
                            <InfiniteScrollSelect
                                id="fund_allocation_fund_id"
                                v-model="fund_allocation[isSubFund ? 'sub_fund_id' : 'fund_id']"
                                :selectedData="selectedFund"
                                :dataType="isSubFund ? 'sub_funds' : 'funds'"
                                :dataIdentifier="isSubFund ? 'sub_fund_id' : 'fund_id'"
                                label="name"
                                apiClient="acquisition"
                                :required="true"
                            />
                            <span class="required">Required</span>
                        </li> -->
                        <li>
                            <label for="fund_allocation_amount" class="required"
                                >{{ $__("Allocation amount") }}:</label
                            >
                            <input
                                id="fund_allocation_amount"
                                v-model="fund_allocation.allocation_amount"
                                type="number"
                                step=".01"
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_allocation_reference"
                                >{{ $__("Reference") }}:</label
                            >
                            <input
                                id="fund_allocation_reference"
                                v-model="fund_allocation.reference"
                                placeholder="Fund allocation reference"
                            />
                        </li>
                        <li>
                            <label for="fund_allocation_note"
                                >{{ $__("Note") }}:
                            </label>
                            <textarea
                                id="fund_allocation_note"
                                v-model="fund_allocation.note"
                                placeholder="Notes"
                                rows="10"
                                cols="50"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <input type="submit" value="Submit" />
                    <router-link
                        :to="{
                            name: 'FundShow',
                            params: { fund_id: selectedFund.fund_id },
                        }"
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}</router-link
                    >
                </fieldset>
            </form>
        </div>
    </div>
</template>

<script>
import { inject, onBeforeMount, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import { setMessage, setWarning } from "../../../messages";
import InfiniteScrollSelect from "../../InfiniteScrollSelect.vue";
import { useRoute, useRouter } from "vue-router";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const route = useRoute();
        const router = useRouter();
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted } = acquisitionsStore;

        const initialized = ref(false);
        const fund_allocation = ref({
            fund_id: null,
            sub_fund_id: null,
            fiscal_period_id: null,
            ledger_id: null,
            reference: "",
            note: "",
            currency: "",
            allocation_amount: null,
            lib_group_visibility: "",
        });
        const selectedFund = ref(null);
        const isSubFund = ref(false);

        const getFundAllocation = fund_allocation_id => {
            const client = APIClient.acquisition;
            client.fundAllocations.get(fund_allocation_id).then(result => {
                fund_allocation.value = result;
            });
        };
        const getFund = params => {
            const { fund_id, sub_fund_id } = params;
            const whichClient = sub_fund_id ? "subFunds" : "funds";
            const whichParam = sub_fund_id ? "sub_fund_id" : "fund_id";
            if (sub_fund_id) isSubFund.value = true;

            const client = APIClient.acquisition;
            client[whichClient].get(params[whichParam]).then(
                result => {
                    selectedFund.value = result;
                    fund_allocation.value[whichParam] = result[whichParam];
                    fund_allocation.value.ledger_id = result.ledger_id;
                    fund_allocation.value.fiscal_period_id =
                        result.fiscal_period_id;
                    fund_allocation.value.currency = result.currency;
                    fund_allocation.value.owner_id = result.owner_id;
                    fund_allocation.value.lib_group_visibility =
                        result.lib_group_visibility;
                },
                error => {}
            );
        };
        const onSubmit = e => {
            e.preventDefault();

            if (!isUserPermitted("createFundAllocation")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create fund allocations."
                    )
                );
                return;
            }

            const fundAllocation = JSON.parse(
                JSON.stringify(fund_allocation.value)
            );
            const fund_allocation_id = fundAllocation.fund_allocation_id;

            delete fundAllocation.fund_allocation_id;

            if (fund_allocation_id) {
                const acq_client = APIClient.acquisition;
                acq_client.fundAllocations
                    .update(fundAllocation, fund_allocation_id)
                    .then(
                        success => {
                            setMessage($__("Fund allocation updated"));
                            router.push({
                                name: "FundShow",
                                params: { fund_id: selectedFund.value.fund_id },
                            });
                        },
                        error => {}
                    );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.fundAllocations.create(fundAllocation).then(
                    success => {
                        setMessage($__("Fund allocation created"));
                        router.push({
                            name: "FundShow",
                            params: { fund_id: selectedFund.value.fund_id },
                        });
                    },
                    error => {}
                );
            }
        };

        onBeforeMount(() => {
            const { params } = route;
            getFund(params).then(() => {
                if (params.fund_allocation_id) {
                    getFundAllocation(params.fund_allocation_id);
                }
                initialized.value = true;
            });
        });

        return {
            isUserPermitted,
            fund_allocation,
            selectedFund,
            isSubFund,
            onSubmit,
        };
    },
    components: {
        InfiniteScrollSelect,
    },
};
</script>

<style scoped>
fieldset.rows label {
    width: 15em;
}
</style>
