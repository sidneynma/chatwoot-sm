import InternalChatAPI from './api';

const state = {
  unreadCount: 0,
};

export const getters = {
  getUnreadCount: $state => $state.unreadCount,
};

export const mutations = {
  SET_UNREAD_COUNT($state, count) {
    $state.unreadCount = Number(count) || 0;
  },
};

export const actions = {
  async fetchUnreadCount({ commit }) {
    try {
      const { data } = await InternalChatAPI.unreadCount();
      commit('SET_UNREAD_COUNT', data.unread_count);
    } catch {
      // ignore — badge is best-effort
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
