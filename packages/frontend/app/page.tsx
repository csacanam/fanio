"use client"

import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import {
  ArrowRight,
  Users,
  TrendingUp,
  Shield,
  Zap,
  DollarSign,
  Gift,
  Ticket,
} from "lucide-react"
import Link from "next/link"

export default function FanioLanding() {
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
    target: 100000,
    current: 67500,
    backers: 1247,
    daysLeft: 23,
    image: "/bad-bunny-concert-reggaeton.png",
    slug: "bad-bunny-new-york-2025",
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-background/95 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 max-w-6xl flex items-center justify-between">
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
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Link href={`/event/${demoEvent.slug}`}>
              <Card className="cursor-pointer fanio-card-hover event-card">
                <div className="relative">
                  <img
                    src={demoEvent.image || "/placeholder.svg"}
                    alt={demoEvent.title}
                    className="w-full h-48 object-cover rounded-t-lg"
                  />
                  <Badge className="absolute top-3 right-3 fanio-gradient text-white border-0">
                    {demoEvent.daysLeft} days left
                  </Badge>
                </div>
                <CardContent className="p-4">
                  <h3 className="font-bold text-lg mb-1 text-balance">{demoEvent.title}</h3>
                  <p className="text-muted-foreground text-sm mb-3">
                    {demoEvent.venue} • {demoEvent.location}
                  </p>

                  <div className="space-y-2 mb-4">
                    <div className="flex justify-between text-sm">
                      <span>${demoEvent.current.toLocaleString('en-US')} raised</span>
                      <span>{((demoEvent.current / demoEvent.target) * 100).toFixed(0)}%</span>
                    </div>
                    <Progress value={(demoEvent.current / demoEvent.target) * 100} className="h-2 progress-bar-glow" />
                    <p className="text-xs text-muted-foreground">Goal: ${demoEvent.target.toLocaleString('en-US')} USDC</p>
                  </div>

                  <div className="flex items-center justify-between text-sm text-muted-foreground">
                    <span>{demoEvent.backers.toLocaleString('en-US')} backers</span>
                    <span className="flex items-center gap-1">
                      <Ticket className="h-4 w-4" />
                      $BBNY25 tokens
                    </span>
                  </div>
                </CardContent>
              </Card>
            </Link>

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
              <p className="text-muted-foreground text-sm">Open market for token trading</p>
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