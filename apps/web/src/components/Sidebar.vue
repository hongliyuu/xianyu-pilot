<template>
  <aside class="sidebar" :class="{ open }">
    <button class="sidebar-close" type="button" aria-label="关闭菜单" @click="$emit('close')">
      <svg viewBox="0 0 24 24" class="ui-icon"><path d="M6 6l12 12M18 6 6 18" /></svg>
    </button>
    <button type="button" class="brand brand-image" aria-label="返回首页" @click="$emit('navigate','dashboard')">
      <img src="/xya/brand/brand_004.png" alt="Xianyu Pilot" class="brand-logo" />
    </button>
    <nav class="nav-scroll">
      <section v-for="group in groups" :key="group.key" class="nav-group">
        <button
          type="button"
          :class="['nav-group-toggle', { contextual: groupContainsActive(group) }]"
          :aria-expanded="isExpanded(group.key)"
          :aria-controls="`nav-group-${group.key}`"
          @click="toggleGroup(group.key)"
        >
          <span class="nav-icon"><Icon :name="group.icon" /></span>
          <span>{{ group.title }}</span>
          <svg class="nav-chevron" :class="{ expanded: isExpanded(group.key) }" viewBox="0 0 24 24" aria-hidden="true">
            <path d="m7 10 5 5 5-5" />
          </svg>
        </button>
        <div :id="`nav-group-${group.key}`" v-show="isExpanded(group.key)" class="nav-group-items">
          <button
            v-for="item in group.items"
            :key="item.key"
            type="button"
            :class="['nav-item', { active: isActive(item.key) }]"
            @click="$emit('navigate', item.key)"
          >
            <span class="nav-icon"><Icon :name="item.icon" /></span>
            <span>{{ item.label }}</span>
            <span v-if="item.badge" class="nav-badge">{{ item.badge }}</span>
          </button>
        </div>
      </section>
    </nav>
    <button type="button" class="side-user" aria-label="打开个人中心" @click="$emit('navigate','profile')">
      <div class="avatar avatar-img"></div>
      <div class="side-user-main">
        <strong>{{ displayName }}</strong>
        <span>管理员</span>
      </div>
      <span class="online-dot"></span><span class="online-text">在线</span>
    </button>
    <button class="sidebar-logout" type="button" @click="$emit('logout')">退出登录</button>
    <div class="version">© {{ copyrightYear }} Xianyu Pilot<br />v{{ APP_VERSION }}</div>
  </aside>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { navGroups } from '../data/nav.js'
import Icon from './Icon.vue'
import { APP_VERSION, getCopyrightYear } from '../utils/appMeta.js'
defineEmits(['navigate', 'close', 'logout'])
const props = defineProps({ active: { type: String, required: true }, user: { type: Object, default: () => ({}) }, open: { type: Boolean, default: false } })
const groups = navGroups
const displayName = computed(() => props.user?.username || props.user?.displayName || props.user?.name || '管理员')
const copyrightYear = getCopyrightYear()
const expandedGroupKeys = ref(new Set())

function isActive(key) {
  if (props.active.startsWith('settings-') && props.active !== 'settings-notify' && key === 'settings-system') return true
  return props.active === key
}

function groupContainsActive(group) {
  return group.items.some(item => isActive(item.key))
}

function isExpanded(key) {
  return expandedGroupKeys.value.has(key)
}

function toggleGroup(key) {
  const next = new Set(expandedGroupKeys.value)
  if (next.has(key)) next.delete(key)
  else next.add(key)
  expandedGroupKeys.value = next
}

watch(
  () => props.active,
  () => {
    const activeGroup = groups.find(group => groupContainsActive(group))
    if (!activeGroup) return
    expandedGroupKeys.value = new Set([...expandedGroupKeys.value, activeGroup.key])
  },
  { immediate: true }
)
</script>
