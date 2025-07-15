<template>
    <div id="fund_transfer_add">
        <h2>{{ $__("Transfer between funds") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label for="fund_transfer_fund_id" class="required"
                                >{{ $__("Fund to transfer to") }}:</label
                            >
                            <InfiniteScrollSelect
                                id="fund_transfer_fund_id"
                                v-model="fund_transfer.fund_id_to"
                                dataType="funds"
                                dataIdentifier="fund_id"
                                label="name"
                                apiClient="acquisition"
                                :required="!fund_transfer.fund_id_to"
                                :filters="{
                                    fund_id: { '!=': $route.query.fund_id },
                                    status: '1',
                                }"
                                @update:modelValue="handleSubFunds"
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label
                                for="fund_transfer_sub_fund"
                                :class="noSubFunds ? '' : 'required'"
                                >{{ $__("Sub fund") }}:</label
                            >
                            <v-select
                                id="fund_transfer_sub_fund"
                                v-model="fund_transfer.sub_fund_id_to"
                                :reduce="av => av.sub_fund_id"
                                :options="subFunds"
                                label="name"
                                :disabled="noSubFunds"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !noSubFunds
                                                ? false
                                                : !fund_transfer.sub_fund_it_to
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span v-if="!noSubFunds" class="required">{{
                                $__("Required")
                            }}</span>
                        </li>
                        <li>
                            <label for="fund_transfer_amount" class="required"
                                >{{ $__("Allocation amount") }}:</label
                            >
                            <input
                                id="fund_transfer_amount"
                                v-model="fund_transfer.transfer_amount"
                                type="number"
                                step=".01"
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_transfer_reference"
                                >{{ $__("Reference") }}:</label
                            >
                            <input
                                id="fund_transfer_reference"
                                v-model="fund_transfer.reference"
                                placeholder="Fund transfer reference"
                            />
                        </li>
                        <li>
                            <label for="fund_transfer_note"
                                >{{ $__("Note") }}:
                            </label>
                            <textarea
                                id="fund_transfer_note"
                                v-model="fund_transfer.note"
                                placeholder="Notes"
                                rows="10"
                                cols="50"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <button
                        class="btn btn-primary"
                        type="submit"
                        :disabled="preventSubmit"
                    >
                        {{ $__("Submit") }}
                    </button>
                    <router-link
                        :to="{
                            name: 'FundShow',
                            params: { fund_id: $route.query.fund_id },
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
import { inject, ref } from "vue";
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

        const subFunds = ref([]);
        const noSubFunds = ref(true);
        const preventSubmit = ref(false);
        const selectedFund = ref(null);

        const { sub_fund_id, fund_id } = route.query;
        const fund_transfer = ref({
            fund_id_from: null,
            sub_fund_id_from: null,
            fund_id_to: null,
            sub_fund_id_to: null,
            reference: "",
            note: "",
            transfer_amount: null,
        });
        if (sub_fund_id)
            fund_transfer.value.sub_fund_id_from = parseInt(sub_fund_id);
        if (fund_id && !sub_fund_id)
            fund_transfer.value.fund_id_from = parseInt(fund_id);

        const getFund = fund_id => {
            const client = APIClient.acquisition;
            client.funds.get(fund_id, { "x-koha-embed": "sub_funds" }).then(
                fund => {
                    selectedFund.value = fund;
                    if (fund.sub_funds && fund.sub_funds.length > 0) {
                        noSubFunds.value = false;
                        subFunds.value = fund.sub_funds;
                    }
                },
                error => {}
            );
        };
        const handleSubFunds = () => {
            preventSubmit.value = true;
            getFund(fund_transfer.value.fund_id_to);
            preventSubmit.value = false;
        };
        const onSubmit = e => {
            e.preventDefault();

            if (!isUserPermitted("createFundAllocation")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to transfer between funds."
                    )
                );
                return;
            }

            const fundTransfer = JSON.parse(
                JSON.stringify(fund_transfer.value)
            );

            const acq_client = APIClient.acquisition;
            acq_client.fundAllocations.transfer(fundTransfer).then(
                success => {
                    setMessage($__("Funds successfully transferred"));
                    router.push({
                        name: "FundShow",
                        params: { fund_id: route.query.fund_id },
                    });
                },
                error => {}
            );
        };

        return {
            isUserPermitted,
            subFunds,
            noSubFunds,
            preventSubmit,
            selectedFund,
            handleSubFunds,
            onSubmit,
            fund_transfer,
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
