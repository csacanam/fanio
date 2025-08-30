"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  ArrowLeft,
  Users,
  TrendingUp,
  MapPin,
  Clock,
  DollarSign,
  Trophy,
  Gift,
  Ticket,
  Zap,
  Info,
} from "lucide-react"
import Link from "next/link"

interface EventPageProps {
  params: {
    slug: string
  }
}

export default function EventPage({ params }: EventPageProps) {
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

  // Mock event data - in real app, this would come from API/database
  const demoEvent = {
    id: "bad-bunny-2025",
    title: "Bad Bunny World Tour 2025",
    artist: "Bad Bunny",
    promoter: "Páramo Presenta",
    promoterDescription: "Top event organizer in Colombia with over 50 successful concerts including major reggaeton and pop artists.",
    venue: "Madison Square Garden",
    date: "2025-12-15",
    location: "New York, NY",
    description:
      "We want to bring Bad Bunny to Madison Square Garden! With his massive popularity and sold-out shows worldwide, we believe there's huge demand for this reggaeton experience in New York. Help us make it happen!",
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

  // Calculate deadline date based on daysLeft
  const getDeadlineDate = (daysLeft: number) => {
    const deadline = new Date()
    deadline.setDate(deadline.getDate() + daysLeft)
    deadline.setHours(23, 59, 59, 999) // Set to 11:59 PM
    return deadline.toLocaleDateString('en-US', { 
      weekday: 'short', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    }) + ' 11:59 PM UTC'
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-background/95 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4 max-w-6xl flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/" className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors">
              <ArrowLeft className="h-5 w-5" />
              Back
            </Link>
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 fanio-gradient rounded-lg flex items-center justify-center music-pulse">
                <Zap className="h-5 w-5 text-white" />
              </div>
              <h1 className="text-2xl font-bold fanio-gradient-text">Fanio</h1>
            </div>
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
                <div className="flex items-center gap-2">
                  <span className="text-lg opacity-90">Presented by</span>
                  <Dialog>
                    <DialogTrigger asChild>
                      <button className="text-lg font-medium underline hover:text-primary transition-colors flex items-center gap-1">
                        {demoEvent.promoter}
                        <Info className="h-4 w-4" />
                      </button>
                    </DialogTrigger>
                    <DialogContent className="sm:max-w-md">
                      <DialogHeader>
                        <DialogTitle className="flex items-center gap-2">
                          <Users className="h-5 w-5 text-primary" />
                          {demoEvent.promoter}
                        </DialogTitle>
                        <DialogDescription className="text-left">
                          Event Promoter
                        </DialogDescription>
                      </DialogHeader>
                      <div className="space-y-4">
                        <p className="text-sm text-muted-foreground leading-relaxed">
                          {demoEvent.promoterDescription}
                        </p>
                        <div className="flex items-center gap-4 text-sm">
                          <div className="flex items-center gap-1">
                            <Trophy className="h-4 w-4 text-primary" />
                            <span className="font-medium">50+</span>
                            <span className="text-muted-foreground">Events</span>
                          </div>
                          <div className="flex items-center gap-1">
                            <MapPin className="h-4 w-4 text-primary" />
                            <span className="text-muted-foreground">Colombia</span>
                          </div>
                        </div>
                        <div className="pt-2 border-t">
                          <p className="text-xs text-muted-foreground">
                            Verified event promoter with proven track record
                          </p>
                        </div>
                      </div>
                    </DialogContent>
                  </Dialog>
                </div>
              </div>
            </div>

            {/* Desktop: Token Perks - appears after banner */}
            <Card className="hidden lg:block">
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

            {/* Mobile: Funding Progress - appears after banner */}
            <div className="lg:hidden">
              <Card>
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
                      <span className="text-2xl font-bold">${currentProgress.toLocaleString('en-US')} USDC</span>
                      <span className="text-sm text-muted-foreground">of ${targetAmount.toLocaleString('en-US')}</span>
                    </div>
                    <Progress value={progressPercentage} className="h-3 progress-bar-glow" />
                    <div className="flex justify-between items-center mt-2">
                      <p className="text-sm text-muted-foreground">{progressPercentage.toFixed(1)}% funded</p>
                      <p className="text-sm text-muted-foreground">{demoEvent.backers.toLocaleString('en-US')} backers</p>
                    </div>
                  </div>

                  {!showMarketplace ? (
                    <div className="space-y-4">
                      <div>
                        <Label htmlFor="investment-mobile">Investment Amount (USDC)</Label>
                        <Input
                          id="investment-mobile"
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
                          $BBNY25 tokens are now trading on the open market
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

                         <div className="text-xs text-muted-foreground p-4 bg-muted/30 rounded-lg border">
                           <p>
                             <strong>All or nothing.</strong> This event will only be funded if it reaches its goal by {getDeadlineDate(demoEvent.daysLeft)}.
                           </p>
                         </div>
                       </CardContent>
                     </Card>
                   </div>

            {/* Mobile: How Fanio Works - appears third */}
            <div className="lg:hidden">
              <Card>
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
                      <p className="text-sm text-muted-foreground">Trade tokens on the open market</p>
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

            {/* Mobile: Token Perks - appears fourth */}
            <div className="lg:hidden">
              <Card>
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



            {/* Mobile: About Event - appears sixth */}
            <div className="lg:hidden">
              <Card>
                <CardHeader>
                  <CardTitle>About This Event</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground leading-relaxed">
                    {demoEvent.description} By funding this event, you'll receive $BBNY25 tokens that give you exclusive
                    perks and the ability to trade on the open market once funding is complete.
                  </p>
                </CardContent>
              </Card>
            </div>



            {/* Desktop: About Event */}
            <Card className="hidden lg:block">
              <CardHeader>
                <CardTitle>About This Event</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground leading-relaxed">
                  {demoEvent.description} By funding this proposal, you'll receive $BBNY25 tokens that give you exclusive
                  perks and the ability to trade on the open market once funding is complete.
                </p>
              </CardContent>
            </Card>


          </div>

          {/* Desktop Sidebar */}
          <div className="space-y-6 hidden lg:block">
            <Card>
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
                    <span className="text-2xl font-bold">${currentProgress.toLocaleString('en-US')} USDC</span>
                    <span className="text-sm text-muted-foreground">of ${targetAmount.toLocaleString('en-US')}</span>
                  </div>
                  <Progress value={progressPercentage} className="h-3 progress-bar-glow" />
                  <div className="flex justify-between items-center mt-2">
                    <p className="text-sm text-muted-foreground">{progressPercentage.toFixed(1)}% funded</p>
                    <p className="text-sm text-muted-foreground">{demoEvent.backers.toLocaleString('en-US')} backers</p>
                  </div>
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
                        $BBNY25 tokens are now trading on the open market
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

                <div className="text-xs text-muted-foreground p-4 bg-muted/30 rounded-lg border">
                  <p>
                    <strong>All or nothing.</strong> This event will only be funded if it reaches its goal by {getDeadlineDate(demoEvent.daysLeft)}.
                  </p>
                </div>
              </CardContent>
            </Card>

            <Card className="lg:sticky lg:top-24">
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
                    <p className="text-sm text-muted-foreground">Trade tokens on the open market</p>
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
