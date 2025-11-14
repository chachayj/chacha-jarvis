<template>
  <div class="log">
    <div v-for="(line, idx) in lines" :key="idx">{{ line }}</div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ lines: string[] }>();
</script>
