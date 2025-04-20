"use client"

import * as React from "react"
import * as SliderPrimitive from "@radix-ui/react-slider"
import { cn } from "@/lib/utils"

const roundUpToNearest5 = (value: number) => Math.ceil(value / 5) * 5;

const Slider = React.forwardRef<
  React.ElementRef<typeof SliderPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SliderPrimitive.Root>
>(({ className, ...props }, ref) => (
  <SliderPrimitive.Root
    ref={ref}
    className={cn(
      "relative flex w-full touch-none select-none items-center",
      className
    )}
    {...props}
  >
    <SliderPrimitive.Track className="relative h-1 w-full grow overflow-hidden rounded-full bg-[#2D3139]">
      <SliderPrimitive.Range className={cn(
        "absolute h-full bg-[#10B981]",
        props.name?.includes("expense") ? "bg-[#EF4444]" : "bg-[#10B981]"
      )} />
    </SliderPrimitive.Track>
    <SliderPrimitive.Thumb className={cn(
      "block h-3 w-3 rounded-full border bg-[#1D2027]",
      props.name?.includes("expense") ? "border-[#EF4444]" : "border-[#10B981]",
      "ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
    )} />
  </SliderPrimitive.Root>
))
Slider.displayName = SliderPrimitive.Root.displayName

export { Slider } 