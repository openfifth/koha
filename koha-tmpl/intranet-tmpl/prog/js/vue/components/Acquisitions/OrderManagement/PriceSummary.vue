<template>
    <br />
    <div style="display: flex; align-items: center">
        <h4>{{ $__("Total prices (for all items) in original currency") }}</h4>
        <ToolTip
            :toolTip="
                $__(
                    'Total price is calculated as follows: vendor price * quantity ordered\nDiscounted price is calculated using the same logic, but subtracting the discount (whether a percentage or amount) from the price before multiplying by the quantity'
                )
            "
        />
    </div>
    <h5>{{ $__("Price") }}: {{ totalPrice }}</h5>
    <h5>{{ $__("Discounted price") }}: {{ totalDiscountedPrice }}</h5>
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
            return formatValueWithCurrency(
                resource.vendor_price * resource.quantity_ordered,
                resource.vendor_price_currency
            );
        });
        const totalDiscountedPrice = computed(() => {
            if (resource.discount_percentage) {
                return formatValueWithCurrency(
                    resource.vendor_price *
                        ((100 - resource.discount_percentage) / 100) *
                        resource.quantity_ordered,
                    resource.vendor_price_currency
                );
            }
            if (resource.discount_amount_oc) {
                return formatValueWithCurrency(
                    (resource.vendor_price - resource.discount_amount_oc) *
                        resource.quantity_ordered,
                    resource.vendor_price_currency
                );
            }
            return totalPrice;
        });
        return {
            totalPrice,
            totalDiscountedPrice,
            formatValueWithCurrency,
        };
    },
};
</script>

<style></style>
