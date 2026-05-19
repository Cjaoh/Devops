/* ── État global ─────────────────────────────────────────────── */
const state = { token: null, user: null };
const API = "/api";

/* ── Utilitaires ─────────────────────────────────────────────── */

function showPage(pageId) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
  document.getElementById(pageId).classList.add("active");
}

function showAlert(elementId, message, type = "error") {
  const el = document.getElementById(elementId);
  if (!el) return;
  el.className = `alert alert-${type}`;
  el.textContent = message;
  el.classList.remove("hidden");
  setTimeout(() => el.classList.add("hidden"), 5000);
}

function switchTab(tabId, btn) {
  document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab").forEach(b => b.classList.remove("active"));
  document.getElementById(tabId).classList.add("active");
  btn.classList.add("active");
  if (tabId === "tab-resources")    loadResources();
  if (tabId === "tab-reservations") loadReservations();
  if (tabId === "tab-new")          loadResourcesSelect();
}

async function apiFetch(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (state.token) headers["Authorization"] = `Bearer ${state.token}`;
  const resp = await fetch(API + path, { ...options, headers });
  if (resp.status === 401) { logout(); return null; }
  return resp;
}

/* ── Authentification ────────────────────────────────────────── */

async function login() {
  const email    = document.getElementById("login-email").value.trim();
  const password = document.getElementById("login-password").value;
  if (!email || !password) return showAlert("login-error", "Veuillez remplir tous les champs.");

  const resp = await fetch(`${API}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await resp.json();
  if (!resp.ok) return showAlert("login-error", data.detail || "Identifiants incorrects.");

  state.token = data.access_token;
  await loadCurrentUser();
  initDashboard();
}

async function register() {
  const full_name = document.getElementById("reg-name").value.trim();
  const email     = document.getElementById("reg-email").value.trim();
  const username  = email.split("@")[0];
  const password  = document.getElementById("reg-password").value;
  if (!full_name || !email || !password) return showAlert("register-error", "Veuillez remplir tous les champs.");

  const resp = await fetch(`${API}/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, full_name, username }),
  });
  const data = await resp.json();
  if (!resp.ok) {
    const msg = data.detail || (data.errors && data.errors[0]?.message) || "Erreur lors de l'inscription.";
    return showAlert("register-error", msg);
  }
  showAlert("register-success", "Compte créé ! Vous pouvez maintenant vous connecter.", "success");
  setTimeout(() => showPage("page-login"), 2000);
}

async function loadCurrentUser() {
  const resp = await apiFetch("/auth/me");
  if (resp && resp.ok) state.user = await resp.json();
}

function logout() {
  state.token = null;
  state.user  = null;
  showPage("page-login");
}

function initDashboard() {
  document.getElementById("nav-username").textContent =
    state.user ? `👤 ${state.user.full_name}` : "";
  showPage("page-dashboard");
  loadResources();
}

/* ── Ressources ──────────────────────────────────────────────── */

async function loadResources() {
  const type   = document.getElementById("filter-type")?.value || "";
  const status = document.getElementById("filter-status")?.value || "";
  let url = "/resources/?";
  if (status === "available") url += "available_only=true&";

  const resp = await apiFetch(url);
  if (!resp || !resp.ok) return;
  const resources = await resp.json();

  // Filtrer par type côté client
  const filtered = type ? resources.filter(r => r.resource_type === type) : resources;
  renderResources(filtered);
}

function renderResources(resources) {
  const container = document.getElementById("resources-list");
  if (!resources.length) {
    container.innerHTML = '<div class="empty-state">Aucune ressource trouvée.</div>';
    return;
  }
  const cards = resources.map(function(r) {
    // is_available peut être absent ou undefined → on considère true par défaut
    const available = (r.is_available === undefined || r.is_available === null) ? true : r.is_available;
    const reserveBtn = available
      ? '<button class="btn btn-sm btn-primary" onclick="prefillReservation(' + r.id + ', \'' + r.name.replace(/'/g, "\\'") + '\')">Réserver</button>'
      : '';
    return '<div class="resource-card">' +
      '<div class="rc-name">' + r.name + '</div>' +
      '<span class="rc-type badge-' + r.resource_type + '">' + typeLabel(r.resource_type) + '</span>' +
      '<div class="rc-desc">' + (r.description || '—') + '</div>' +
      '<div class="rc-meta">📍 ' + (r.location || '—') + ' · 👥 ' + (r.capacity || 1) + ' place(s)</div>' +
      '<div class="rc-footer">' +
        '<span class="status-dot status-' + (available ? 'available' : 'unavailable') + '">' +
          (available ? '✅ Disponible' : '❌ Indisponible') +
        '</span>' +
        reserveBtn +
      '</div>' +
    '</div>';
  });
  container.innerHTML = cards.join("");
}

function prefillReservation(resourceId, resourceName) {
  document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab").forEach(b => b.classList.remove("active"));
  document.getElementById("tab-new").classList.add("active");
  document.querySelectorAll(".tab")[2].classList.add("active");
  loadResourcesSelect(resourceId);
}

async function loadResourcesSelect(preselect) {
  preselect = preselect || null;
  const resp = await apiFetch("/resources/?available_only=true");
  if (!resp || !resp.ok) return;
  const resources = await resp.json();
  const sel = document.getElementById("res-resource");
  sel.innerHTML = '<option value="">— Sélectionner une ressource —</option>' +
    resources.map(function(r) {
      return '<option value="' + r.id + '"' + (preselect == r.id ? ' selected' : '') + '>' + r.name + '</option>';
    }).join("");
}

/* ── Réservations ────────────────────────────────────────────── */

async function loadReservations() {
  const resp = await apiFetch("/reservations/?my_only=true");
  if (!resp || !resp.ok) return;
  const reservations = await resp.json();
  renderReservations(reservations);
}

function renderReservations(reservations) {
  const container = document.getElementById("reservations-list");
  if (!reservations.length) {
    container.innerHTML = '<div class="empty-state">Aucune réservation pour le moment.</div>';
    return;
  }
  const rows = reservations.map(function(r) {
    const actionBtn = r.status === "confirmed"
      ? '<button class="btn btn-sm btn-danger" onclick="cancelReservation(' + r.id + ')">Annuler</button>'
      : '—';
    return '<tr>' +
      '<td>' + r.id + '</td>' +
      '<td>ID ' + r.resource_id + '</td>' +
      '<td>' + formatDate(r.start_at) + '</td>' +
      '<td>' + formatDate(r.end_at) + '</td>' +
      '<td>' + (r.title || r.purpose || '—') + '</td>' +
      '<td><span class="pill pill-' + r.status + '">' + statusLabel(r.status) + '</span></td>' +
      '<td>' + actionBtn + '</td>' +
    '</tr>';
  }).join("");
  container.innerHTML = '<table class="reservations-table"><thead><tr>' +
    '<th>#</th><th>Ressource</th><th>Début</th><th>Fin</th><th>Motif</th><th>Statut</th><th>Action</th>' +
    '</tr></thead><tbody>' + rows + '</tbody></table>';
}

async function makeReservation() {
  const resource_id = document.getElementById("res-resource").value;
  const start_at    = document.getElementById("res-start").value;
  const end_at      = document.getElementById("res-end").value;
  const purpose     = document.getElementById("res-purpose").value.trim();
  const notes       = document.getElementById("res-notes").value.trim();

  if (!resource_id || !start_at || !end_at)
    return showAlert("new-error", "Veuillez remplir les champs obligatoires.");

  const resp = await apiFetch("/reservations/", {
    method: "POST",
    body: JSON.stringify({
      resource_id: parseInt(resource_id),
      start_at:    new Date(start_at).toISOString(),
      end_at:      new Date(end_at).toISOString(),
      purpose:     purpose || "Réservation",
      notes:       notes || "",
    }),
  });
  if (!resp) return;
  const data = await resp.json();
  if (!resp.ok) {
    return showAlert("new-error", data.detail || "Erreur lors de la réservation.");
  }
  showAlert("new-success", "✅ Réservation #" + data.id + " confirmée !", "success");
  document.getElementById("res-resource").value = "";
  document.getElementById("res-start").value    = "";
  document.getElementById("res-end").value      = "";
  document.getElementById("res-purpose").value  = "";
  document.getElementById("res-notes").value    = "";
  setTimeout(function() {
    switchTab("tab-reservations", document.querySelectorAll(".tab")[1]);
  }, 1500);
}

async function cancelReservation(id) {
  if (!confirm("Annuler la réservation #" + id + " ?")) return;
  const resp = await apiFetch("/reservations/" + id, { method: "DELETE" });
  if (!resp) return;
  if (resp.ok || resp.status === 204 || resp.status === 200) {
    loadReservations();
  } else {
    const data = await resp.json();
    alert(data.detail || "Erreur lors de l'annulation.");
  }
}

/* ── Helpers ─────────────────────────────────────────────────── */

function formatDate(iso) {
  return new Date(iso).toLocaleString("fr-FR", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

function typeLabel(type) {
  const labels = {
    vehicule: "🚗 Véhicule", equipement: "🔧 Équipement",
    salle: "🏢 Salle", autre: "📦 Autre",
    vehicle: "🚗 Véhicule", equipment: "🔧 Équipement",
    room: "🏢 Salle", other: "📦 Autre",
  };
  return labels[type] || type;
}

function statusLabel(status) {
  const labels = {
    available: "Disponible", maintenance: "Maintenance", retired: "Retiré",
    confirmed: "Confirmé", cancelled: "Annulé", completed: "Terminé", pending: "En attente",
  };
  return labels[status] || status;
}
