"use client"

import * as React from "react"
import * as SliderPrimitive from "@radix-ui/react-slider"
import { cn } from "@/lib/utils"

const Slider = React.forwardRef<
  React.ElementRef<typeof SliderPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SliderPrimitive.Root> & {
    variant?: "income" | "expense"
  }
>(({ className, variant = "income", ...props }, ref) => (
  <SliderPrimitive.Root
    ref={ref}
    className={cn(
      "relative flex w-full touch-none select-none items-center",
      className
    )}
    {...props}
  >
    <SliderPrimitive.Track className="relative h-1.5 w-full grow overflow-hidden rounded-full bg-[#2D3139]">
      <SliderPrimitive.Range className={cn(
        "absolute h-full",
        variant === "expense" ? "bg-[#dc6868]" : "bg-[#4aba91]"
      )} />
    </SliderPrimitive.Track>
    <SliderPrimitive.Thumb
      className={cn(
        "block h-3 w-3 rounded-full border bg-[#1D2027] ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
        variant === "expense" ? "border-[#dc6868]" : "border-[#4aba91]"
      )}
    />
  </SliderPrimitive.Root>
))
Slider.displayName = SliderPrimitive.Root.displayName

export { Slider } 