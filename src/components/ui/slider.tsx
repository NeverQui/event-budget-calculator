import * as React from "react"
import * as SliderPrimitive from "@radix-ui/react-slider"
import { cn } from "@/lib/utils"

const roundUpToNearest5 = (value: number) => Math.ceil(value / 5) * 5;

const Slider = React.forwardRef<
  React.ElementRef<typeof SliderPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SliderPrimitive.Root> & {
    className?: string;
    onValueChange?: (value: number[]) => void;
  }
>(({ className, onValueChange, value, ...props }, ref) => (
  <SliderPrimitive.Root
    ref={ref}
    value={value}
    onValueChange={onValueChange}
    className={cn(
      "relative flex w-full touch-none select-none items-center py-3",
      className
    )}
    {...props}
  >
    <SliderPrimitive.Track className="relative h-2 w-full grow cursor-pointer overflow-hidden rounded-full bg-[#2D3139]">
      <SliderPrimitive.Range className={cn(
        "absolute h-full bg-[#10B981]",
        className?.includes("expense-slider") ? "bg-[#EF4444]" : ""
      )} />
    </SliderPrimitive.Track>
    <SliderPrimitive.Thumb 
      className={cn(
        "block h-4 w-4 rounded-full border-2 bg-[#1D2027] transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
        className?.includes("expense-slider") ? "border-[#EF4444] hover:border-[#FF6B6B]" : "border-[#10B981] hover:border-[#34D399]"
      )}
      onDoubleClick={() => {
        if (value && onValueChange && Array.isArray(value)) {
          const roundedValue = roundUpToNearest5(value[0]);
          onValueChange([roundedValue]);
        }
      }}
    />
  </SliderPrimitive.Root>
))
Slider.displayName = SliderPrimitive.Root.displayName

export { Slider } 