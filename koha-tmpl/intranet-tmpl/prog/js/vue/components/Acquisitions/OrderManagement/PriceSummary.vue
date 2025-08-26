<template>
    <br />
    <div style="display: flex; align-items: center">
        <h4>{{ $__("Total prices (for all items) in fund currency") }}</h4>
        <ToolTip
            :toolTip="
                $__(
                    'Total price is calculated as follows: vendor price * quantity ordered\nDiscounted price is calculated using the same logic, but subtracting the discount (whether a percentage or amount) from the price before multiplying by the quantity'
                )
            "
        />
    </div>
    <h5>
        {{ $__("Price") }}:
        {{
            totalPrice
                ? formatValueWithCurrency(
                      totalPrice,
                      resource.vendor_price_currency
                  )
                : formatValueWithCurrency(0, resource.vendor_price_currency)
        }}
    </h5>
    <h5>
        {{ $__("Discounted price") }}:
        {{
            totalDiscountedPrice
                ? formatValueWithCurrency(
                      totalDiscountedPrice,
                      resource.vendor_price_currency
                  )
                : formatValueWithCurrency(0, resource.vendor_price_currency)
        }}
    </h5>
    <h5>
        {{ $__("Total cost (tax included)") }}:
        {{
            totalCostTaxIncluded
                ? formatValueWithCurrency(
                      totalCostTaxIncluded,
                      resource.vendor_price_currency
                  )
                : formatValueWithCurrency(0, resource.vendor_price_currency)
        }}
    </h5>
    <h5>
        {{ $__("Total cost (tax excluded)") }}:
        {{
            totalCostTaxExcluded
                ? formatValueWithCurrency(
                      totalCostTaxExcluded,
                      resource.vendor_price_currency
                  )
                : formatValueWithCurrency(0, resource.vendor_price_currency)
        }}
    </h5>
</template>

<script>
import { computed, inject } from "vue";
import ToolTip from "../../ToolTip.vue";
export default {
    components: { ToolTip },
    inheritAttrs: false,
    props: {
        resource: Object,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency } = acquisitionsStore;

        const { resource } = props;
        const totalPrice = computed(() => {
            return resource.vendor_price * resource.quantity_ordered;
        });
        const totalDiscountedPrice = computed(() => {
            if (resource.discount_percentage) {
                return (
                    resource.vendor_price *
                    ((100 - resource.discount_percentage) / 100) *
                    resource.quantity_ordered
                );
            }
            if (resource.discount_amount_oc) {
                return (
                    (resource.vendor_price - resource.discount_amount_oc) *
                    resource.quantity_ordered
                );
            }
            return totalPrice.value;
        });
        const totalCostTaxIncluded = computed(() => {
            const priceToTax = totalDiscountedPrice.value
                ? totalDiscountedPrice.value
                : totalPrice.value;
            return priceToTax * (1 + resource.tax_rate);
        });
        const totalCostTaxExcluded = computed(() => {
            const totalCost = totalDiscountedPrice.value
                ? totalDiscountedPrice.value
                : totalPrice.value;
            return totalCost;
        });
        return {
            totalPrice,
            totalDiscountedPrice,
            formatValueWithCurrency,
            totalCostTaxIncluded,
            totalCostTaxExcluded,
        };
    },
};
</script>

<style></style>
