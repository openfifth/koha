<template>
    <div>
        <h2>{{ $__("Shibboleth Configuration") }}</h2>
        <p>
            {{
                $__(
                    "Configure Shibboleth authentication for your Koha installation"
                )
            }}
        </p>
    </div>
</template>

<script>
export default {
    name: "ShibbolethHome",
};
</script>
