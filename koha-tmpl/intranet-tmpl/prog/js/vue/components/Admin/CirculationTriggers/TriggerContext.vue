<template>
    <div class="page-section">
        <table>
            <thead>
                <th>
                    {{ $__("Loan period") }}
                </th>
                <th>
                    {{ $__("Unit") }}
                </th>
                <th>
                    {{ $__("Decreased loan period for high holds") }}
                </th>
                <th>
                    {{ $__("Fine amount") }}
                </th>
                <th>
                    {{ $__("Fine charging interval") }}
                </th>
            </thead>
            <tbody>
                <tr>
                    <td>
                        {{ ruleSetInfo.issuelength }}
                    </td>
                    <td>
                        {{ ruleSetInfo.lengthunit }}
                    </td>
                    <td>
                        {{ ruleSetInfo.decreaseloanholds }}
                    </td>
                    <td>
                        {{ ruleSetInfo.fine }}
                    </td>
                    <td>
                        {{ ruleSetInfo.chargeperiod }}
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</template>

<script>
export default {
    props: ["ruleSetInfo"],
};
</script>

<style scoped>
table {
    margin: auto;
    width: fit-content;
}
</style>
