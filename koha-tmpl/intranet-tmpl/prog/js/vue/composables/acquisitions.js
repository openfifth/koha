import { BigNumber } from "bignumber.js";

BigNumber.config({ DECIMAL_PLACES: 6 });

const formatFloatingPoint = value => {
    return new BigNumber(value).decimalPlaces(6).toNumber();
};

export const acquisitionsActions = store => {
    return {
        formatFloatingPoint,
    };
};
