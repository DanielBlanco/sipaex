// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/sipaex"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const setupLedgerExchangeRates = () => {
  const accountSelect = document.getElementById("ledger_transaction_bank_account_id")
  const exchangeRateInput = document.getElementById("ledger_transaction_exchange_rate")

  if (!accountSelect || !exchangeRateInput) return

  const syncExchangeRate = () => {
    const selectedOption = accountSelect.selectedOptions[0]
    const exchangeRate = selectedOption?.dataset.exchangeRate

    if (exchangeRate !== undefined) {
      exchangeRateInput.value = exchangeRate
    }
  }

  accountSelect.addEventListener("change", syncExchangeRate)
  syncExchangeRate()
}

const setupLedgerExchangeDifferenceRates = () => {
  const accountSelect = document.getElementById("exchange_difference_bank_account_id")
  const purchaseRateInput = document.getElementById("exchange_difference_purchase_exchange_rate")

  if (!accountSelect || !purchaseRateInput) return

  const syncPurchaseRate = () => {
    const selectedOption = accountSelect.selectedOptions[0]
    const exchangeRate = selectedOption?.dataset.exchangeRate

    if (exchangeRate !== undefined) {
      purchaseRateInput.value = exchangeRate
    }
  }

  accountSelect.addEventListener("change", syncPurchaseRate)
  syncPurchaseRate()
}

const setupLedgerTabs = () => {
  const tabContainer = document.getElementById("ledger-tabs")
  const tabs = document.querySelectorAll("[data-ledger-tab]")
  const panels = document.querySelectorAll("[data-ledger-panel]")

  if (!tabContainer || !tabs.length || !panels.length) return

  const activate = (name) => {
    tabs.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.ledgerTab === name)
    })

    panels.forEach((panel) => {
      panel.hidden = panel.dataset.ledgerPanel !== name
    })
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activate(tab.dataset.ledgerTab))
  })

  activate(tabContainer.dataset.activeLedgerTab || "dashboard")
}

const setupDividendsTabs = () => {
  const tabContainer = document.getElementById("dividends-tabs")
  const tabs = document.querySelectorAll("[data-dividends-tab]")
  const panels = document.querySelectorAll("[data-dividends-panel]")

  if (!tabContainer || !tabs.length || !panels.length) return

  const activate = (name) => {
    tabs.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.dividendsTab === name)
    })

    panels.forEach((panel) => {
      panel.hidden = panel.dataset.dividendsPanel !== name
    })
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activate(tab.dataset.dividendsTab))
  })

  document.querySelectorAll("[data-dividends-tab-target]").forEach((button) => {
    button.addEventListener("click", () => activate(button.dataset.dividendsTabTarget))
  })

  activate(tabContainer.dataset.activeDividendsTab || "wizard")
}

const setupExpensesExchangeRates = () => {
  const pairs = [
    ["expense_entry_currency_id", "expense_entry_exchange_rate"],
    ["financial_entry_currency_id", "financial_entry_exchange_rate"],
  ]

  pairs.forEach(([selectId, inputId]) => {
    const currencySelect = document.getElementById(selectId)
    const exchangeRateInput = document.getElementById(inputId)

    if (!currencySelect || !exchangeRateInput) return

    const syncExchangeRate = () => {
      const selectedOption = currencySelect.selectedOptions[0]
      const exchangeRate = selectedOption?.dataset.exchangeRate

      if (exchangeRate !== undefined) {
        exchangeRateInput.value = exchangeRate
      }
    }

    currencySelect.addEventListener("change", syncExchangeRate)
    syncExchangeRate()
  })
}

const setupExpensesTabs = () => {
  const tabContainer = document.getElementById("expenses-tabs")
  const tabs = document.querySelectorAll("[data-expenses-tab]")
  const panels = document.querySelectorAll("[data-expenses-panel]")

  if (!tabContainer || !tabs.length || !panels.length) return

  const activate = (name) => {
    tabs.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.expensesTab === name)
    })

    panels.forEach((panel) => {
      panel.hidden = panel.dataset.expensesPanel !== name
    })
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activate(tab.dataset.expensesTab))
  })

  activate(tabContainer.dataset.activeExpensesTab || "dashboard")
}

const setupTaxesExchangeRates = () => {
  const pairs = [
    ["income_tax_entry_currency_id", "income_tax_entry_exchange_rate"],
    ["vat_period_currency_id", "vat_period_exchange_rate"],
  ]

  pairs.forEach(([selectId, inputId]) => {
    const currencySelect = document.getElementById(selectId)
    const exchangeRateInput = document.getElementById(inputId)

    if (!currencySelect || !exchangeRateInput) return

    const syncExchangeRate = () => {
      const selectedOption = currencySelect.selectedOptions[0]
      const exchangeRate = selectedOption?.dataset.exchangeRate

      if (exchangeRate !== undefined) {
        exchangeRateInput.value = exchangeRate
      }
    }

    currencySelect.addEventListener("change", syncExchangeRate)
    syncExchangeRate()
  })
}

const setupTaxesTabs = () => {
  const tabContainer = document.getElementById("taxes-tabs")
  const tabs = document.querySelectorAll("[data-taxes-tab]")
  const panels = document.querySelectorAll("[data-taxes-panel]")

  if (!tabContainer || !tabs.length || !panels.length) return

  const activate = (name) => {
    tabs.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.taxesTab === name)
    })

    panels.forEach((panel) => {
      panel.hidden = panel.dataset.taxesPanel !== name
    })
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activate(tab.dataset.taxesTab))
  })

  activate(tabContainer.dataset.activeTaxesTab || "dashboard")
}

const setupCommerceTabs = () => {
  const tabContainer = document.querySelector("[data-active-commerce-tab]")
  const tabs = document.querySelectorAll("[data-commerce-tab]")
  const panels = document.querySelectorAll("[data-commerce-panel]")

  if (!tabContainer || !tabs.length || !panels.length) return

  const activate = (name) => {
    tabs.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.commerceTab === name)
    })

    panels.forEach((panel) => {
      panel.hidden = panel.dataset.commercePanel !== name
    })
  }

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => activate(tab.dataset.commerceTab))
  })

  activate(tabContainer.dataset.activeCommerceTab || "dashboard")
}

const setupCommerceExchangeRates = () => {
  const currencySelect = document.getElementById("commerce_entry_currency_id")
  const exchangeRateInput = document.getElementById("commerce_entry_exchange_rate")

  if (!currencySelect || !exchangeRateInput) return

  const syncExchangeRate = () => {
    const selectedOption = currencySelect.selectedOptions[0]
    const exchangeRate = selectedOption?.dataset.exchangeRate

    if (exchangeRate !== undefined) {
      exchangeRateInput.value = exchangeRate
    }
  }

  currencySelect.addEventListener("change", () => {
    syncExchangeRate()
    document.dispatchEvent(new CustomEvent("commerce:currency-changed"))
  })
  syncExchangeRate()
}

const setupCommerceReceiptLines = () => {
  const tableBody = document.querySelector("[data-commerce-lines]")
  const addButton = document.querySelector("[data-commerce-add-line]")
  const receiptSubtotal = document.querySelector("[data-commerce-receipt-subtotal]")
  const receiptVat = document.querySelector("[data-commerce-receipt-vat]")
  const receiptTotal = document.querySelector("[data-commerce-receipt-total]")

  if (!tableBody || !addButton) return

  const lineTemplate = tableBody.querySelector("[data-commerce-line]")
  const noteTemplate = lineTemplate?.nextElementSibling?.matches("[data-commerce-note-row]")
    ? lineTemplate.nextElementSibling
    : null

  if (!lineTemplate || !noteTemplate) return

  const renumberLine = (line, index) => {
    const noteRow = line.nextElementSibling?.matches("[data-commerce-note-row]")
      ? line.nextElementSibling
      : null

    const rows = [line, noteRow].filter(Boolean)

    rows.forEach((row) => {
      row.querySelectorAll("[name]").forEach((field) => {
        field.name = field.name.replace(/commerce_entry\[lines\]\[\d+\]/, `commerce_entry[lines][${index}]`)
      })

      row.querySelectorAll("[id]").forEach((field) => {
        field.id = field.id.replace(/purchase_line_\d+_/, `purchase_line_${index}_`)
      })
    })
  }

  const numberFromField = (line, selector) => {
    const value = line.querySelector(selector)?.value
    const number = Number.parseFloat(value)

    return Number.isFinite(number) ? number : 0
  }

  const selectedVatRate = (line) => {
    const selectedOption = line.querySelector("[name$='[vat_rate_id]']")?.selectedOptions[0]
    const rate = Number.parseFloat(selectedOption?.dataset.rate)

    return Number.isFinite(rate) ? rate : 0
  }

  const currencySymbol = () => {
    const currencySelect = document.getElementById("commerce_entry_currency_id")

    return currencySelect?.selectedOptions[0]?.dataset.currencySymbol || ""
  }

  const formatMoney = (amount) => {
    const formatted = amount.toLocaleString("es-CR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })

    return `${currencySymbol()}${formatted}`
  }

  const normalizeText = (value) => {
    return value
      .toString()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
  }

  const filterProductPicker = (picker) => {
    const searchInput = picker.querySelector("[data-product-search]")
    const results = picker.querySelector("[data-product-results]")
    const empty = picker.querySelector("[data-product-empty]")
    const query = normalizeText(searchInput?.value || "")
    let visibleCount = 0

    picker.querySelectorAll("[data-product-option]").forEach((option) => {
      const matches = normalizeText(option.dataset.productSearchText || "").includes(query)
      option.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    if (empty) empty.classList.toggle("hidden", visibleCount > 0)
    if (results) results.classList.toggle("hidden", false)
  }

  const closeProductPickers = (exceptPicker = null) => {
    tableBody.querySelectorAll("[data-product-picker]").forEach((picker) => {
      if (picker !== exceptPicker) {
        picker.querySelector("[data-product-results]")?.classList.add("hidden")
      }
    })
  }

  const clearProductPicker = (picker) => {
    const idInput = picker.querySelector("[data-product-id-input]")
    if (idInput) idInput.value = ""
  }

  const refreshTotals = () => {
    let subtotal = 0
    let vat = 0

    tableBody.querySelectorAll("[data-commerce-line]").forEach((line) => {
      const quantity = numberFromField(line, "[name$='[quantity]']")
      const unitPrice = numberFromField(line, "[name$='[unit_price]']")
      const lineSubtotal = quantity * unitPrice
      const lineVat = lineSubtotal * selectedVatRate(line)

      subtotal += lineSubtotal
      vat += lineVat

      const lineSubtotalCell = line.querySelector("[data-commerce-line-subtotal]")
      if (lineSubtotalCell) lineSubtotalCell.textContent = formatMoney(lineSubtotal)
    })

    if (receiptSubtotal) receiptSubtotal.textContent = formatMoney(subtotal)
    if (receiptVat) receiptVat.textContent = formatMoney(vat)
    if (receiptTotal) receiptTotal.textContent = formatMoney(subtotal + vat)
  }

  const syncRemoveButtons = () => {
    const lines = tableBody.querySelectorAll("[data-commerce-line]")

    lines.forEach((line, index) => {
      renumberLine(line, index)

      const removeButton = line.querySelector("[data-commerce-remove-line]")
      if (removeButton) removeButton.disabled = lines.length === 1
    })

    refreshTotals()
  }

  addButton.addEventListener("click", () => {
    const nextLine = lineTemplate.cloneNode(true)
    const nextNote = noteTemplate.cloneNode(true)

    nextLine.querySelectorAll("input").forEach((input) => {
      if (input.name.includes("[quantity]")) {
        input.value = "1"
      } else {
        input.value = ""
      }
    })

    nextNote.querySelectorAll("input").forEach((input) => {
      input.value = ""
    })

    nextLine.querySelector("[data-product-results]")?.classList.add("hidden")
    nextNote.classList.add("hidden")

    tableBody.appendChild(nextLine)
    tableBody.appendChild(nextNote)
    syncRemoveButtons()
  })

  tableBody.addEventListener("input", refreshTotals)
  tableBody.addEventListener("change", refreshTotals)
  document.addEventListener("commerce:currency-changed", refreshTotals)

  tableBody.addEventListener("focusin", (event) => {
    const searchInput = event.target.closest("[data-product-search]")

    if (!searchInput) return

    const picker = searchInput.closest("[data-product-picker]")
    closeProductPickers(picker)
    filterProductPicker(picker)
  })

  tableBody.addEventListener("input", (event) => {
    const searchInput = event.target.closest("[data-product-search]")

    if (!searchInput) return

    const picker = searchInput.closest("[data-product-picker]")
    clearProductPicker(picker)
    filterProductPicker(picker)
  })

  tableBody.addEventListener("click", (event) => {
    const productOption = event.target.closest("[data-product-option]")

    if (productOption) {
      const picker = productOption.closest("[data-product-picker]")
      const idInput = picker.querySelector("[data-product-id-input]")
      const searchInput = picker.querySelector("[data-product-search]")

      if (idInput) idInput.value = productOption.dataset.productId || ""
      if (searchInput) searchInput.value = productOption.dataset.productLabel || ""

      picker.querySelector("[data-product-results]")?.classList.add("hidden")
      return
    }

    const noteButton = event.target.closest("[data-commerce-toggle-note]")

    if (noteButton) {
      const line = noteButton.closest("[data-commerce-line]")
      const noteRow = line?.nextElementSibling?.matches("[data-commerce-note-row]")
        ? line.nextElementSibling
        : null

      noteRow?.classList.toggle("hidden")
      return
    }

    const removeButton = event.target.closest("[data-commerce-remove-line]")

    if (!removeButton) return

    const line = removeButton.closest("[data-commerce-line]")
    const noteRow = line?.nextElementSibling?.matches("[data-commerce-note-row]")
      ? line.nextElementSibling
      : null

    noteRow?.remove()
    line?.remove()
    syncRemoveButtons()
  })

  syncRemoveButtons()

  document.addEventListener("click", (event) => {
    if (!event.target.closest("[data-product-picker]")) {
      closeProductPickers()
    }
  })
}

const setupModalOpeners = () => {
  document.querySelectorAll("[data-modal-target]").forEach((button) => {
    button.addEventListener("click", () => {
      document.getElementById(button.dataset.modalTarget)?.showModal()
    })
  })
}

document.addEventListener("DOMContentLoaded", () => {
  setupLedgerExchangeRates()
  setupLedgerExchangeDifferenceRates()
  setupLedgerTabs()
  setupDividendsTabs()
  setupExpensesExchangeRates()
  setupExpensesTabs()
  setupTaxesExchangeRates()
  setupTaxesTabs()
  setupCommerceTabs()
  setupCommerceExchangeRates()
  setupCommerceReceiptLines()
  setupModalOpeners()
})

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
