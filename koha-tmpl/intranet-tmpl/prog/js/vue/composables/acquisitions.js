import { BigNumber } from "bignumber.js";

BigNumber.config({ DECIMAL_PLACES: 6 });

const formatFloatingPoint = value => {
    // Convert via String first so JS's shortest-representation algorithm recovers
    // the intended decimal (e.g. String(17.9549999...) === "17.955"), then round
    // to 2dp with BigNumber before converting to a plain number so that
    // format_price's toFixed(2) always receives a pre-rounded value.
    return new BigNumber(String(value ?? 0))
        .decimalPlaces(2, BigNumber.ROUND_HALF_UP)
        .toNumber();
};

const formatValueWithCurrencyHandler = (value, currency, store) => {
    const formattedPrice = formatFloatingPoint(value).format_price();
    if (!currency) {
        return formattedPrice;
    }
    if (!value) {
        return `0 ${currency}`;
    }
    if (!formattedPrice) {
        return `0 ${currency}`;
    }
    if (formattedPrice < 0) {
        return `-${-formattedPrice} ${currency}`;
    }
    return `${formattedPrice} ${currency}`;
};

export const acquisitionsActions = store => {
    return {
        formatFloatingPoint,
        formatValueWithCurrency(value, currency) {
            return formatValueWithCurrencyHandler(value, currency, store);
        },
    };
};
