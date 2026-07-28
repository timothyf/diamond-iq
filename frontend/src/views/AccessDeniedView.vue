<script setup>
import { useRouter } from 'vue-router'

const router = useRouter()
</script>

<template>
  <main class="access-denied-shell">
    <section class="access-denied-card">
      <p class="eyebrow">Restricted workspace</p>
      <h1>Administrator access required</h1>
      <p>Your account can use the baseball intelligence workspace, but Admin tools are limited to administrators.</p>
      <button type="button" @click="router.push({ name: 'home' })">Return home</button>
    </section>
  </main>
</template>

<style scoped>
.access-denied-shell { min-height: calc(100vh - 74px); display: grid; place-items: center; padding: 2rem; background: linear-gradient(145deg,#f7f1e3,#ead8b6); color: #10263d; }
.access-denied-card { width: min(520px,100%); padding: 2.2rem; border: 1px solid rgba(16,38,61,.14); border-radius: 24px; background: rgba(255,252,244,.94); box-shadow: 0 20px 50px rgba(64,43,20,.12); }
.eyebrow { color: #b79569; font-size: .68rem; font-weight: 900; letter-spacing: .12em; text-transform: uppercase; }
h1 { margin: .35rem 0; font-family: 'Avenir Next Condensed', sans-serif; font-size: 2.6rem; line-height: .95; text-transform: uppercase; }
p:not(.eyebrow) { color: #71808c; font-size: .85rem; line-height: 1.5; }
button { margin-top: .8rem; padding: .7rem 1rem; border: 0; border-radius: 9px; color: #fffaf0; background: #20543c; font: inherit; font-weight: 900; }
</style>
