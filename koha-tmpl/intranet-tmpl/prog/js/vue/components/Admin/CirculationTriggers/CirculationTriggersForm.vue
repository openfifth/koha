<template>
    <form
        id="circulation-trigger-form"
        @submit="submitAction($event)"
        class="modal-content"
    >
        <div class="modal-header">
            <h1 class="modal-title">
                {{ $__(formTitle) }}
            </h1>
            <router-link
                class="btn-close"
                type="button"
                :to="{
                    name: 'CirculationTriggersList',
                }"
            ></router-link>
        </div>
        <div class="modal-body">
            <slot></slot>
        </div>
        <div class="modal-footer">
            <ButtonSubmit :title="buttonText" />
            <router-link
                :to="{
                    name: 'CirculationTriggersList',
                }"
                >{{ $__("Cancel") }}
            </router-link>
        </div>
    </form>
</template>
<script>
import ButtonSubmit from "../../ButtonSubmit.vue";
export default {
    props: ["submitAction", "formTitle", "buttonText"],
    components: { ButtonSubmit },
};
</script>
<style scoped>
#circulation-trigger-form {
    max-height: 90vh;
}
</style>
