import { APIClient } from "../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export function useAllocationModal({
    entity,
    acquisitionsStore,
    setConfirmationDialog,
    setWarning,
    setMessage,
    onSuccess,
}) {
    const { formatValueWithCurrency, applyNumberValidation } =
        acquisitionsStore;
    const isFund = entity === "fund";
    const breachAmountMessage = $__(
        "The parent amount will be breached by %s. Please reduce the amount for this allocation."
    );

    const openAllocationModal = (resource, action) => {
        const entityId = resource[entity + "_id"];
        const isIncrease = action === "increase";
        const isDecrease = action === "decrease";
        const isTransfer = action === "transfer";

        const title = isIncrease
            ? isFund
                ? $__("Increase fund amount")
                : $__("Increase ledger amount")
            : isDecrease
              ? isFund
                  ? $__("Decrease fund amount")
                  : $__("Decrease ledger amount")
              : isFund
                ? $__("Transfer fund amount")
                : $__("Transfer ledger amount");

        const allocationAmountLabel = isIncrease
            ? $__("Increase amount by")
            : isDecrease
              ? $__("Decrease amount by")
              : $__("Amount being transferred");

        const remainingAmountLabel = isIncrease
            ? isFund
                ? $__("Increased fund amount")
                : $__("Increased ledger amount")
            : isDecrease
              ? isFund
                  ? $__("Decreased fund amount")
                  : $__("Decreased ledger amount")
              : isFund
                ? $__("Remaining fund amount")
                : $__("Remaining ledger amount");

        APIClient.acquisition[entity + "s"].get(entityId).then(result => {
            const ledger = isFund ? result.ledger : result;
            const currency = ledger?.currency;
            const entityAmount = result[entity + "_amount"];
            const fiscalPeriodName = result.fiscal_period?.name;
            const ledgerName = ledger?.name;
            const fundName = isFund ? result.name : null;

            setConfirmationDialog(
                {
                    title,
                    accept_label: $__("Save"),
                    cancel_label: $__("Cancel"),
                    size: "modal-lg",
                    inputs: [
                        {
                            name: "fiscal_period_name",
                            type: "display",
                            label: $__("Fiscal period"),
                            value: fiscalPeriodName,
                        },
                        {
                            name: "ledger_name",
                            type: "display",
                            label: $__("Ledger"),
                            value: ledgerName,
                        },
                        ...(isFund
                            ? [
                                  {
                                      name: "fund_name",
                                      type: "display",
                                      label: $__("Fund"),
                                      value: fundName,
                                  },
                              ]
                            : []),
                        {
                            name: "current_amount",
                            type: "display",
                            label: $__("Current amount"),
                            value: formatValueWithCurrency(
                                entityAmount,
                                currency
                            ),
                        },
                        {
                            name: "allocation_amount",
                            type: "number",
                            label: allocationAmountLabel,
                            required: true,
                            ...applyNumberValidation(),
                        },
                        ...(isTransfer
                            ? [
                                  {
                                      name: "is_transferred_to",
                                      type: "relationshipSelect",
                                      label: isFund
                                          ? $__("Destination fund")
                                          : $__("Destination ledger"),
                                      relationshipAPIClient:
                                          APIClient.acquisition[
                                              isFund ? "funds" : "ledgers"
                                          ],
                                      relationshipOptionLabelAttr: "name",
                                      relationshipRequiredKey: isFund
                                          ? "fund_id"
                                          : "ledger_id",
                                      query: {
                                          [isFund ? "fund_id" : "ledger_id"]: {
                                              "!=": entityId,
                                          },
                                      },
                                      required: true,
                                  },
                              ]
                            : []),
                        {
                            name: "reference",
                            type: "text",
                            label: $__("Reference"),
                        },
                        {
                            name: "note",
                            type: "text",
                            label: $__("Note"),
                        },
                        {
                            name: "remaining_amount",
                            type: "display",
                            label: remainingAmountLabel,
                            format: (value, resource) => {
                                const allocated =
                                    parseFloat(resource.allocation_amount) || 0;
                                const remainder = isIncrease
                                    ? entityAmount + allocated
                                    : entityAmount - allocated;
                                resource.remaining_amount = remainder;
                                return formatValueWithCurrency(
                                    remainder,
                                    currency
                                );
                            },
                        },
                    ],
                },
                async (confirmation, inputFields) => {
                    const allocated =
                        parseFloat(inputFields.allocation_amount) || 0;
                    const remaining = isIncrease
                        ? entityAmount + allocated
                        : entityAmount - allocated;

                    if (remaining < 0) {
                        setWarning(
                            $__(
                                "Insufficient funds to process this transaction, please adjust the allocation amount"
                            )
                        );
                        return;
                    }

                    const allocation = {
                        allocation_amount: allocated,
                        type: action,
                        [entity + "_id"]: parseInt(entityId),
                        ...(isTransfer && inputFields.is_transferred_to
                            ? {
                                  is_transferred_to:
                                      inputFields.is_transferred_to,
                              }
                            : {}),
                        reference: inputFields.reference || null,
                        note: inputFields.note || null,
                    };

                    await APIClient.acquisition.allocations
                        .create(allocation)
                        .then(
                            () => {
                                setMessage($__("Allocation created"));
                                onSuccess?.();
                            },
                            error => {
                                setWarning(
                                    breachAmountMessage.format(
                                        formatValueWithCurrency(
                                            error.result.breach_amount
                                        )
                                    )
                                );
                            }
                        );
                }
            );
        });
    };

    return { openAllocationModal };
}
