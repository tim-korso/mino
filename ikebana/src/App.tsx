import { useState } from 'react'
import NavBar, { BrandHeader, type NavPage } from './components/NavBar'
import Dashboard from './pages/Dashboard'
import ItemList from './pages/ItemList'
import ItemDetail from './pages/ItemDetail'
import ClearingFlow from './pages/ClearingFlow'
import Achievements from './pages/Achievements'
import { useItems } from './hooks/useItems'
import type { Item } from './data/mock'

export default function App() {
  const { items, addItem } = useItems()
  const [page, setPage] = useState<NavPage>('dashboard')
  const [selectedItem, setSelectedItem] = useState<Item | null>(null)

  const handleSelectItem = (item: Item) => {
    setSelectedItem(item)
  }

  const handleBackFromDetail = () => {
    setSelectedItem(null)
  }

  const handleStartClearing = (item: Item) => {
    void item
    setPage('clearing')
  }

  const handleNavigate = (p: NavPage) => {
    setSelectedItem(null)
    setPage(p)
  }

  const renderPage = () => {
    if (selectedItem && page === 'items') {
      return (
        <ItemDetail
          item={selectedItem}
          onBack={handleBackFromDetail}
          onStartClearing={handleStartClearing}
        />
      )
    }

    switch (page) {
      case 'dashboard':
        return <Dashboard items={items} onNavigate={handleNavigate} />
      case 'items':
        return <ItemList items={items} onSelectItem={handleSelectItem} onAddItem={addItem} />
      case 'clearing':
        return <ClearingFlow items={items} onNavigate={handleNavigate} />
      case 'achievements':
        return <Achievements />
    }
  }

  return (
    <div className="min-h-screen bg-paper">
      <header className="sticky top-0 z-30 bg-paper/80 backdrop-blur-lg border-b border-[var(--border-light)]">
        <div className="max-w-3xl mx-auto px-5 py-3">
          <BrandHeader />
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-5 pt-5">
        {renderPage()}
      </main>

      <NavBar current={page} onChange={handleNavigate} />
    </div>
  )
}

