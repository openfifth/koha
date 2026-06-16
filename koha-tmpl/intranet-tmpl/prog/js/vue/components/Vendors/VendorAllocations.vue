<template>
    <fieldset class="rows">
        <table v-if="allocations.length || showAddForm">
            <thead>
                <tr>
                    <th>{{ $__("Budget period") }}</th>
                    <th>{{ $__("Allocation amount") }}</th>
                    <th>{{ $__("Warn at (%)") }}</th>
                    <th>{{ $__("Warn at (amount)") }}</th>
                    <th>&nbsp;</th>
                </tr>
            </thead>
            <tbody>
                <tr v-for="allocation in allocations" :key="allocation.allocation_id">
                    <template v-if="editingId === allocation.allocation_id">
                        <td>
                            <select v-model="editForm.budget_period_id">
                                <option
                                    v-for="period in availablePeriods(allocation.budget_period_id)"
                                    :key="period.budget_period_id"
                                    :value="period.budget_period_id"
                                >
                                    {{ period.description }}
                                </option>
                            </select>
                        </td>
                        <td>
                            <input
                                type="number"
                                step="0.01"
                                min="0"
                                v-model.number="editForm.allocation_amount"
                            />
                        </td>
                        <td>
                            <input
                                type="number"
                                step="0.01"
                                min="0"
                                max="100"
                                v-model.number="editForm.warn_at_percentage"
                            />
                        </td>
                        <td>
                            <input
                                type="number"
                                step="0.01"
                                min="0"
                                v-model.number="editForm.warn_at_amount"
                            />
                        </td>
                        <td>
                            <button
                                class="btn btn-default btn-xs"
                                @click="saveEdit(allocation)"
                            >
                                {{ $__("Save") }}
                            </button>
                            <button
                                class="btn btn-default btn-xs"
                                @click="cancelEdit"
                            >
                                {{ $__("Cancel") }}
                            </button>
                        </td>
                    </template>
                    <template v-else>
                        <td>{{ periodLabel(allocation.budget_period_id) }}</td>
                        <td>{{ allocation.allocation_amount }}</td>
                        <td>{{ allocation.warn_at_percentage }}</td>
                        <td>{{ allocation.warn_at_amount }}</td>
                        <td>
                            <button
                                class="btn btn-default btn-xs"
                                @click="startEdit(allocation)"
                            >
                                <i class="fa-solid fa-pencil" aria-hidden="true"></i>
                                {{ $__("Edit") }}
                            </button>
                            <button
                                class="btn btn-default btn-xs"
                                @click="deleteAllocation(allocation)"
                            >
                                <i class="fa-solid fa-trash-can" aria-hidden="true"></i>
                                {{ $__("Delete") }}
                            </button>
                        </td>
                    </template>
                </tr>
                <tr v-if="showAddForm">
                    <td>
                        <select v-model="addForm.budget_period_id">
                            <option value="">{{ $__("Select a budget period") }}</option>
                            <option
                                v-for="period in unallocatedPeriods"
                                :key="period.budget_period_id"
                                :value="period.budget_period_id"
                            >
                                {{ period.description }}
                            </option>
                        </select>
                    </td>
                    <td>
                        <input
                            type="number"
                            step="0.01"
                            min="0"
                            v-model.number="addForm.allocation_amount"
                        />
                    </td>
                    <td>
                        <input
                            type="number"
                            step="0.01"
                            min="0"
                            max="100"
                            v-model.number="addForm.warn_at_percentage"
                        />
                    </td>
                    <td>
                        <input
                            type="number"
                            step="0.01"
                            min="0"
                            v-model.number="addForm.warn_at_amount"
                        />
                    </td>
                    <td>
                        <button
                            class="btn btn-default btn-xs"
                            @click="saveAdd"
                            :disabled="!addForm.budget_period_id"
                        >
                            {{ $__("Add") }}
                        </button>
                        <button
                            class="btn btn-default btn-xs"
                            @click="cancelAdd"
                        >
                            {{ $__("Cancel") }}
                        </button>
                    </td>
                </tr>
            </tbody>
        </table>
        <p v-else>{{ $__("No vendor allocations defined.") }}</p>
        <button
            v-if="!showAddForm"
            class="btn btn-default btn-xs"
            @click="openAddForm"
        >
            <i class="fa fa-plus" aria-hidden="true"></i>
            {{ $__("Add allocation") }}
        </button>
        <div v-if="error" class="alert alert-danger">{{ error }}</div>
    </fieldset>
</template>

<script>
import { ref, computed, onMounted } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        vendor: Object,
    },
    setup(props) {
        const allocations = ref([]);
        const budgetPeriods = ref([]);
        const editingId = ref(null);
        const editForm = ref({});
        const showAddForm = ref(false);
        const addForm = ref({
            budget_period_id: "",
            allocation_amount: 0,
            warn_at_percentage: 0,
            warn_at_amount: 0,
        });
        const error = ref(null);

        const loadAllocations = async () => {
            allocations.value = await APIClient.acquisition.vendor_allocations.getAll(
                props.vendor.id
            );
        };

        const loadBudgetPeriods = async () => {
            budgetPeriods.value = await APIClient.acquisition.budget_periods.getAll();
        };

        onMounted(async () => {
            await Promise.all([loadAllocations(), loadBudgetPeriods()]);
        });

        const periodLabel = budget_period_id => {
            const period = budgetPeriods.value.find(
                p => p.budget_period_id === budget_period_id
            );
            return period ? period.description : budget_period_id;
        };

        const usedPeriodIds = computed(() =>
            allocations.value.map(a => a.budget_period_id)
        );

        const unallocatedPeriods = computed(() =>
            budgetPeriods.value.filter(
                p => !usedPeriodIds.value.includes(p.budget_period_id)
            )
        );

        const availablePeriods = currentPeriodId =>
            budgetPeriods.value.filter(
                p =>
                    p.budget_period_id === currentPeriodId ||
                    !usedPeriodIds.value.includes(p.budget_period_id)
            );

        const startEdit = allocation => {
            editingId.value = allocation.allocation_id;
            editForm.value = {
                budget_period_id: allocation.budget_period_id,
                allocation_amount: allocation.allocation_amount,
                warn_at_percentage: allocation.warn_at_percentage,
                warn_at_amount: allocation.warn_at_amount,
            };
        };

        const cancelEdit = () => {
            editingId.value = null;
            editForm.value = {};
            error.value = null;
        };

        const saveEdit = async allocation => {
            error.value = null;
            try {
                await APIClient.acquisition.vendor_allocations.update(
                    props.vendor.id,
                    allocation.allocation_id,
                    editForm.value
                );
                await loadAllocations();
                editingId.value = null;
                editForm.value = {};
            } catch (e) {
                error.value = $__("Failed to update allocation.");
            }
        };

        const deleteAllocation = async allocation => {
            error.value = null;
            try {
                await APIClient.acquisition.vendor_allocations.delete(
                    props.vendor.id,
                    allocation.allocation_id
                );
                await loadAllocations();
            } catch (e) {
                error.value = $__("Failed to delete allocation.");
            }
        };

        const openAddForm = () => {
            showAddForm.value = true;
            addForm.value = {
                budget_period_id: "",
                allocation_amount: 0,
                warn_at_percentage: 0,
                warn_at_amount: 0,
            };
            error.value = null;
        };

        const cancelAdd = () => {
            showAddForm.value = false;
            error.value = null;
        };

        const saveAdd = async () => {
            error.value = null;
            try {
                await APIClient.acquisition.vendor_allocations.create(
                    props.vendor.id,
                    addForm.value
                );
                await loadAllocations();
                showAddForm.value = false;
            } catch (e) {
                error.value = $__("Failed to create allocation. An allocation for this budget period may already exist.");
            }
        };

        return {
            allocations,
            budgetPeriods,
            editingId,
            editForm,
            showAddForm,
            addForm,
            error,
            periodLabel,
            unallocatedPeriods,
            availablePeriods,
            startEdit,
            cancelEdit,
            saveEdit,
            deleteAllocation,
            openAddForm,
            cancelAdd,
            saveAdd,
            $__,
        };
    },
};
</script>
