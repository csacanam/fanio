"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  ArrowRight,
  Users,
  TrendingUp,
  Shield,
  Zap,
  Calendar,
  MapPin,
  Clock,
  DollarSign,
  Trophy,
  Gift,
  Ticket,
} from "lucide-react"

export default function FanioLanding() {
  const [selectedEvent, setSelectedEvent] = useState<string | null>(null)
  const [investmentAmount, setInvestmentAmount] = useState("")
  const [currentProgress, setCurrentProgress] = useState(67500)
  const [isSimulating, setIsSimulating] = useState(false)
  const [showMarketplace, setShowMarketplace] = useState(false)

  const targetAmount = 100000
  const progressPercentage = (currentProgress / targetAmount) * 100

  // Simulate investment progress
  const simulateInvestment = () => {
    if (!investmentAmount || isSimulating) return

    setIsSimulating(true)
    const amount = Number.parseFloat(investmentAmount)
    const newProgress = Math.min(currentProgress + amount, targetAmount)

    // Animate progress bar
    const increment = (newProgress - currentProgress) / 20
    let current = currentProgress

    const interval = setInterval(() => {
      current += increment
      setCurrentProgress(Math.min(current, newProgress))

      if (current >= newProgress) {
        clearInterval(interval)
        setIsSimulating(false)

        // If target reached, show marketplace
        if (newProgress >= targetAmount) {
          setTimeout(() => setShowMarketplace(true), 1000)
        }
      }
    }, 50)

    setInvestmentAmount("")
  }

  const scrollToEvents = () => {
    const eventsSection = document.getElementById("active-events")
    if (eventsSection) {
      eventsSection.scrollIntoView({ behavior: "smooth" })
    }
  }

  const demoEvent = {
    id: "bad-bunny-2025",
    title: "Bad Bunny World Tour 2025",
    artist: "Bad Bunny",
    venue: "Madison Square Garden",
    date: "2025-12-15",
    location: "New York, NY",
    description:
      "Experience the most anticipated reggaeton concert of the year with Bad Bunny at the iconic Madison Square Garden.",
    target: targetAmount,
    current: currentProgress,
    backers: 1247,
    daysLeft: 23,
    image: "/bad-bunny-concert-reggaeton.png",
  }

  const perks = [
    { tokens: 100, title: "Early Access", description: "Get tickets 24h before general sale", icon: Clock },
    { tokens: 250, title: "VIP Discount", description: "20% off VIP packages", icon: Trophy },
    { tokens: 500, title: "Exclusive Merch", description: "Limited edition tour merchandise", icon: Gift },
    { tokens: 1000, title: "Backstage Pass", description: "Meet & greet opportunity", icon: Users },
  ]

  if (selectedEvent) {
    return (
      <div className="min-h-screen bg-background">
        {/* Header */}
        <header className="border-b bg-card/50 backdrop-blur-sm sticky top-0 z-50">
          <div className="container mx-auto px-4 py-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <button onClick={() => setSelectedEvent(null)} className="text-muted-foreground hover:text-foreground">
                ← Back
              </button>
              <h1 className="text-2xl font-bold text-primary">Fanio</h1>
            </div>
            <Badge variant="secondary">Demo Event</Badge>
          </div>
        </header>

        <div className="container mx-auto px-4 py-8 max-w-6xl">
          <div className="space-y-8 lg:grid lg:grid-cols-3 lg:gap-8 lg:space-y-0">
            {/* Event Details */}
            <div className="lg:col-span-2 space-y-6">
              <div className="relative">
                <img
                  src={demoEvent.image || "/placeholder.svg"}
                  alt={demoEvent.title}
                  className="w-full h-64 object-cover rounded-lg"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent rounded-lg" />
                <div className="absolute bottom-4 left-4 text-white">
                  <h1 className="text-3xl font-bold text-balance">{demoEvent.title}</h1>
                  <p className="text-lg opacity-90">{demoEvent.artist}</p>
                </div>
              </div>

              <div className="grid md:grid-cols-3 gap-4 order-4 lg:order-none">
                <Card>
                  <CardContent className="p-4 flex items-center gap-3">
                    <Calendar className="h-5 w-5 text-primary" />
                    <div>
                      <p className="font-medium">Date</p>
                      <p className="text-sm text-muted-foreground">Dec 15, 2025</p>
                    </div>
                  </CardContent>
                </Card>
                <Card>
                  <CardContent className="p-4 flex items-center gap-3">
                    <MapPin className="h-5 w-5 text-primary" />
                    <div>
                      <p className="font-medium">Venue</p>
                      <p className="text-sm text-muted-foreground">{demoEvent.venue}</p>
                    </div>
                  </CardContent>
                </Card>
                <Card>
                  <CardContent className="p-4 flex items-center gap-3">
                    <Users className="h-5 w-5 text-primary" />
                    <div>
                      <p className="font-medium">Backers</p>
                      <p className="text-sm text-muted-foreground">{demoEvent.backers.toLocaleString()}</p>
                    </div>
                  </CardContent>
                </Card>
              </div>

              <Card className="order-5 lg:order-none">
                <CardHeader>
                  <CardTitle>About This Event</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground leading-relaxed">
                    {demoEvent.description} By funding this event, you'll receive $BBNY25 tokens that give you exclusive
                    perks and the ability to trade on the free market once funding is complete.
                  </p>
                </CardContent>
              </Card>

              <Card className="order-3 lg:order-none">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Gift className="h-5 w-5" />
                    Token Perks & Utilities
                  </CardTitle>
                  <CardDescription>What you can do with your $BBNY25 tokens</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="grid md:grid-cols-2 gap-4">
                    {perks.map((perk, index) => (
                      <div key={index} className="flex items-start gap-3 p-3 rounded-lg border">
                        <perk.icon className="h-5 w-5 text-primary mt-0.5" />
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="font-medium">{perk.title}</span>
                            <Badge variant="outline" className="text-xs">
                              {perk.tokens} tokens
                            </Badge>
                          </div>
                          <p className="text-sm text-muted-foreground">{perk.description}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>

            <div className="space-y-6">
              <Card className="lg:sticky lg:top-24 order-1 lg:order-none">
                <CardHeader>
                  <CardTitle className="flex items-center justify-between">
                    Funding Progress
                    <Badge variant={showMarketplace ? "default" : "secondary"}>
                      {showMarketplace ? "Market Open" : `${demoEvent.daysLeft} days left`}
                    </Badge>
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div>
                    <div className="flex justify-between items-center mb-2">
                      <span className="text-2xl font-bold">${currentProgress.toLocaleString()} USDC</span>
                      <span className="text-sm text-muted-foreground">of ${targetAmount.toLocaleString()}</span>
                    </div>
                    <Progress value={progressPercentage} className="h-3 progress-bar-glow" />
                    <p className="text-sm text-muted-foreground mt-2">{progressPercentage.toFixed(1)}% funded</p>
                  </div>

                  {!showMarketplace ? (
                    <div className="space-y-4">
                      <div>
                        <Label htmlFor="investment">Investment Amount (USDC)</Label>
                        <Input
                          id="investment"
                          type="number"
                          placeholder="Enter amount"
                          value={investmentAmount}
                          onChange={(e) => setInvestmentAmount(e.target.value)}
                          className="mt-1"
                        />
                      </div>
                      <Button
                        onClick={simulateInvestment}
                        disabled={!investmentAmount || isSimulating}
                        className="w-full fanio-button-glow"
                        size="lg"
                      >
                        {isSimulating ? "Processing..." : "Fund This Event"}
                        <DollarSign className="ml-2 h-4 w-4" />
                      </Button>
                      <p className="text-xs text-muted-foreground text-center">
                        You'll receive $BBNY25 tokens equal to your USDC investment
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-4">
                      <div className="text-center p-4 bg-primary/10 rounded-lg">
                        <TrendingUp className="h-8 w-8 text-primary mx-auto mb-2" />
                        <h3 className="font-semibold text-primary">Funding Complete!</h3>
                        <p className="text-sm text-muted-foreground mt-1">
                          $BBNY25 tokens are now trading on the free market
                        </p>
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        <Button variant="outline" size="sm">
                          Buy $BBNY25
                        </Button>
                        <Button variant="outline" size="sm">
                          Sell $BBNY25
                        </Button>
                      </div>
                      <div className="text-center text-sm text-muted-foreground">
                        <p>Current Price: $1.20 USDC</p>
                        <p className="text-primary">+20% from funding price</p>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>

              <Card className="lg:sticky lg:top-[32rem] order-2 lg:order-none">
                <CardHeader>
                  <CardTitle className="text-lg">How Fanio Works</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-start gap-3">
                    <div className="w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
                      1
                    </div>
                    <div>
                      <p className="font-medium">Fund the Event</p>
                      <p className="text-sm text-muted-foreground">Buy $BBNY25 tokens with USDC</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
                      2
                    </div>
                    <div>
                      <p className="font-medium">Event Gets Funded</p>
                      <p className="text-sm text-muted-foreground">Organizer receives USDC when goal is met</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
                      3
                    </div>
                    <div>
                      <p className="font-medium">Market Opens</p>
                      <p className="text-sm text-muted-foreground">Trade tokens on the free market</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-6 h-6 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center font-bold">
                      4
                    </div>
                    <div>
                      <p className="font-medium">Enjoy Perks</p>
                      <p className="text-sm text-muted-foreground">Use tokens for exclusive benefits</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 fanio-gradient rounded-lg flex items-center justify-center music-pulse">
              <Zap className="h-5 w-5 text-white" />
            </div>
            <h1 className="text-2xl font-bold fanio-gradient-text">Fanio</h1>
          </div>
          <Button variant="outline" className="cursor-pointer bg-transparent">
            Connect Wallet
          </Button>
        </div>
      </header>

      {/* Hero Section */}
      <section className="py-20 px-4">
        <div className="container mx-auto text-center max-w-4xl">
          <h1 className="text-5xl md:text-6xl font-bold text-balance mb-6">
            From Fans to <span className="fanio-gradient-text">Stakeholders</span>
          </h1>
          <p className="text-xl text-muted-foreground text-balance mb-8 max-w-2xl mx-auto leading-relaxed">
            Help make concerts happen and earn tradeable tokens with exclusive perks.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button size="lg" className="text-lg px-8 cursor-pointer fanio-button-glow" onClick={scrollToEvents}>
              Explore Events
              <ArrowRight className="ml-2 h-5 w-5" />
            </Button>
            <Button size="lg" variant="outline" className="text-lg px-8 bg-transparent cursor-pointer">
              How It Works
            </Button>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 px-4 bg-muted/30">
        <div className="container mx-auto max-w-6xl">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4">Why Fanio?</h2>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto text-balance">
              Revolutionary crowdfunding that empowers fans and eliminates traditional barriers
            </p>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            <Card className="text-center">
              <CardContent className="p-6">
                <Users className="h-12 w-12 text-primary mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">Fan Empowerment</h3>
                <p className="text-muted-foreground">
                  Fans become stakeholders with voting rights and exclusive perks, not just ticket buyers.
                </p>
              </CardContent>
            </Card>
            <Card className="text-center">
              <CardContent className="p-6">
                <TrendingUp className="h-12 w-12 text-primary mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">Liquid Assets</h3>
                <p className="text-muted-foreground">
                  Event tokens become tradeable assets on the secondary market with automatic liquidity.
                </p>
              </CardContent>
            </Card>
            <Card className="text-center">
              <CardContent className="p-6">
                <Shield className="h-12 w-12 text-primary mx-auto mb-4" />
                <h3 className="text-xl font-semibold mb-2">Trustless Funding</h3>
                <p className="text-muted-foreground">
                  Smart contracts ensure transparent, all-or-nothing funding with automatic distribution.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Active Events */}
      <section id="active-events" className="py-16 px-4">
        <div className="container mx-auto max-w-6xl">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h2 className="text-3xl font-bold mb-2">Active Events</h2>
              <p className="text-muted-foreground">Fund the next big shows and earn exclusive perks</p>
            </div>
            {/* <Button variant="outline">View All</Button> */}
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Card className="cursor-pointer fanio-card-hover event-card" onClick={() => setSelectedEvent("demo")}>
              <div className="relative">
                <img
                  src={demoEvent.image || "/placeholder.svg"}
                  alt={demoEvent.title}
                  className="w-full h-48 object-cover rounded-t-lg"
                />
                <Badge className="absolute top-3 right-3 fanio-gradient text-white border-0">{demoEvent.daysLeft} days left</Badge>
              </div>
              <CardContent className="p-4">
                <h3 className="font-bold text-lg mb-1 text-balance">{demoEvent.title}</h3>
                <p className="text-muted-foreground text-sm mb-3">
                  {demoEvent.venue} • {demoEvent.location}
                </p>

                <div className="space-y-2 mb-4">
                  <div className="flex justify-between text-sm">
                    <span>${demoEvent.current.toLocaleString()} raised</span>
                    <span>{((demoEvent.current / demoEvent.target) * 100).toFixed(0)}%</span>
                  </div>
                  <Progress value={(demoEvent.current / demoEvent.target) * 100} className="h-2 progress-bar-glow" />
                  <p className="text-xs text-muted-foreground">Goal: ${demoEvent.target.toLocaleString()} USDC</p>
                </div>

                <div className="flex items-center justify-between text-sm text-muted-foreground">
                  <span>{demoEvent.backers} backers</span>
                  <span className="flex items-center gap-1">
                    <Ticket className="h-4 w-4" />
                    $BBNY25 tokens
                  </span>
                </div>
              </CardContent>
            </Card>

            {/* Placeholder cards */}
            <Card className="opacity-50">
              <div className="relative">
                <img
                  src="/taylor-swift-concert-stage.png"
                  alt="Coming Soon"
                  className="w-full h-48 object-cover rounded-t-lg"
                />
                <Badge variant="secondary" className="absolute top-3 right-3">
                  Coming Soon
                </Badge>
              </div>
              <CardContent className="p-4">
                <h3 className="font-bold text-lg mb-1">Taylor Swift Eras Tour</h3>
                <p className="text-muted-foreground text-sm mb-3">MetLife Stadium • East Rutherford, NJ</p>
                <p className="text-sm text-muted-foreground">Funding opens soon...</p>
              </CardContent>
            </Card>

            <Card className="opacity-50">
              <div className="relative">
                <img
                  src="/drake-concert-hip-hop-stage.png"
                  alt="Coming Soon"
                  className="w-full h-48 object-cover rounded-t-lg"
                />
                <Badge variant="secondary" className="absolute top-3 right-3">
                  Coming Soon
                </Badge>
              </div>
              <CardContent className="p-4">
                <h3 className="font-bold text-lg mb-1">Drake World Tour</h3>
                <p className="text-muted-foreground text-sm mb-3">Crypto.com Arena • Los Angeles, CA</p>
                <p className="text-sm text-muted-foreground">Funding opens soon...</p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-16 px-4 bg-muted/30">
        <div className="container mx-auto max-w-6xl">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4">How Fanio Works</h2>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto text-balance">
              A simple 4-step process that revolutionizes event funding
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            <div className="text-center">
              <div className="w-16 h-16 fanio-gradient rounded-full flex items-center justify-center mx-auto mb-4 music-pulse">
                <DollarSign className="h-8 w-8 text-white" />
              </div>
              <h3 className="font-semibold text-lg mb-2">1. Fund Events</h3>
              <p className="text-muted-foreground text-sm">Buy event tokens with USDC to fund your favorite shows</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 fanio-gradient rounded-full flex items-center justify-center mx-auto mb-4 music-pulse">
                <TrendingUp className="h-8 w-8 text-white" />
              </div>
              <h3 className="font-semibold text-lg mb-2">2. Goal Reached</h3>
              <p className="text-muted-foreground text-sm">Organizer receives full funding when target is met</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 fanio-gradient rounded-full flex items-center justify-center mx-auto mb-4 music-pulse">
                <Users className="h-8 w-8 text-white" />
              </div>
              <h3 className="font-semibold text-lg mb-2">3. Market Opens</h3>
              <p className="text-muted-foreground text-sm">Free market opens for token trading</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 fanio-gradient rounded-full flex items-center justify-center mx-auto mb-4 music-pulse">
                <Gift className="h-8 w-8 text-white" />
              </div>
              <h3 className="font-semibold text-lg mb-2">4. Enjoy Perks</h3>
              <p className="text-muted-foreground text-sm">Use tokens for exclusive access, discounts, and more</p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4">
        <div className="container mx-auto text-center max-w-3xl">
          <h2 className="text-4xl font-bold mb-4 text-balance">Ready to Join the Revolution?</h2>
          <p className="text-xl text-muted-foreground mb-8 text-balance">
            Be part of the future where fans become stakeholders and events get the funding they deserve.
          </p>
          <Button size="lg" className="text-lg px-8 cursor-pointer fanio-button-glow" onClick={scrollToEvents}>
            Start Funding Events
            <ArrowRight className="ml-2 h-5 w-5" />
          </Button>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t py-12 px-4 bg-muted/30">
        <div className="container mx-auto max-w-6xl">
          <div className="grid md:grid-cols-4 gap-8">
            <div>
              <div className="flex items-center gap-2 mb-4">
                <div className="w-8 h-8 fanio-gradient rounded-lg flex items-center justify-center">
                  <Zap className="h-5 w-5 text-white" />
                </div>
                <h3 className="text-xl font-bold fanio-gradient-text">Fanio</h3>
              </div>
              <p className="text-muted-foreground text-sm">
                Trustless crowdfunding for live events powered by blockchain technology.
              </p>
            </div>
            <div>
              <h4 className="font-semibold mb-3">Platform</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>
                  <a href="#" className="hover:text-foreground">
                    How It Works
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    Active Events
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    Create Event
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold mb-3">Support</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>
                  <a href="#" className="hover:text-foreground">
                    FAQ
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    Documentation
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold mb-3">Community</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>
                  <a href="#" className="hover:text-foreground">
                    Discord
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    Twitter
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-foreground">
                    GitHub
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t mt-8 pt-8 text-center text-sm text-muted-foreground">
            <p>&copy; 2024 Fanio. All rights reserved. Built with ❤️ for the music community.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
