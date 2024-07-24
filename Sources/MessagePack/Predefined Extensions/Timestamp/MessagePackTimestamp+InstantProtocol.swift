// MIT License
//
// Copyright © 2023 Darren Mo.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

extension MessagePackTimestamp: InstantProtocol {
   public static func <(lhs: MessagePackTimestamp, rhs: MessagePackTimestamp) -> Bool {
      if lhs.secondsComponent < rhs.secondsComponent {
         return true
      } else if lhs.secondsComponent > rhs.secondsComponent {
         return false
      } else {
         return lhs.nanosecondsComponent < rhs.nanosecondsComponent
      }
   }

   public func advanced(by duration: Duration) -> MessagePackTimestamp {
      let (secondsToAdd, attosecondsToAdd) = duration.components
      precondition(attosecondsToAdd >= 0)

      var secondsComponent = secondsComponent + secondsToAdd

      var (nanosecondsToAdd, remainder) = attosecondsToAdd.quotientAndRemainder(dividingBy: 1_000_000_000)
      if remainder > 500_000_000 || (remainder == 500_000_000 && !nanosecondsToAdd.isMultiple(of: 2)) {
         nanosecondsToAdd += 1
      }

      var nanosecondsComponent = Int64(nanosecondsComponent) + nanosecondsToAdd
      if nanosecondsComponent > Self.nanosecondsComponentMax {
         secondsComponent += 1
         nanosecondsComponent -= 1_000_000_000
      }

      return MessagePackTimestamp(secondsComponent: secondsComponent,
                                  nanosecondsComponent: UInt32(nanosecondsComponent))
   }

   public func duration(to other: MessagePackTimestamp) -> Duration {
      let secondsToOther = other.secondsComponent - self.secondsComponent
      let nanosecondsToOther = Int64(other.nanosecondsComponent) - Int64(self.nanosecondsComponent)

      return .seconds(secondsToOther) + .nanoseconds(nanosecondsToOther)
   }
}


public struct Duration: Equatable {
    private let totalSeconds: Int64
    private let attoseconds: Int64  // Attoseconds, where 1 nanosecond = 1e9 attoseconds

    public init(secondsComponent: Int64, attosecondsComponent: Int64) {
        var effectiveSeconds = secondsComponent
        var effectiveAttoseconds = attosecondsComponent

        // Normalize attoseconds to be within 0 to 999,999,999,999,999,999
        effectiveSeconds += effectiveAttoseconds / 1_000_000_000_000_000_000
        effectiveAttoseconds = effectiveAttoseconds % 1_000_000_000_000_000_000

        // Adjust for negative attoseconds
        if effectiveAttoseconds < 0 {
            effectiveAttoseconds += 1_000_000_000_000_000_000
            effectiveSeconds -= 1
        }

        self.totalSeconds = effectiveSeconds
        self.attoseconds = effectiveAttoseconds
    }

    public var components: (seconds: Int64, attoseconds: Int64) {
        return (totalSeconds, attoseconds)
    }

    public static func seconds(_ seconds: Int64) -> Duration {
        return Duration(secondsComponent: seconds, attosecondsComponent: 0)
    }

    // Handle nanoseconds input by converting them to attoseconds
    public static func nanoseconds(_ nanoseconds: Int64) -> Duration {
        let attoseconds = nanoseconds * 1_000_000_000  // Convert nanoseconds to attoseconds
        return Duration(secondsComponent: 0, attosecondsComponent: attoseconds)
    }

    public static func attoseconds(_ attoseconds: Int64) -> Duration {
        return Duration(secondsComponent: 0, attosecondsComponent: attoseconds)
    }

    public static func +(lhs: Duration, rhs: Duration) -> Duration {
        let combinedSeconds = lhs.totalSeconds + rhs.totalSeconds
        let combinedAttoseconds = lhs.attoseconds + rhs.attoseconds
        return Duration(secondsComponent: combinedSeconds, attosecondsComponent: combinedAttoseconds)
    }
}

// 定义 `InstantProtocol`
public protocol InstantProtocol: Comparable {
    func advanced(by duration: Duration) -> Self
    func duration(to other: Self) -> Duration
}


/*
 
 extension MessagePackTimestamp: InstantProtocol {
     public static func < (lhs: MessagePackTimestamp, rhs: MessagePackTimestamp) -> Bool {
         if lhs.secondsComponent < rhs.secondsComponent {
             return true
         } else if lhs.secondsComponent > rhs.secondsComponent {
             return false
         } else {
             return lhs.nanosecondsComponent < rhs.nanosecondsComponent
         }
     }

     public static func == (lhs: MessagePackTimestamp, rhs: MessagePackTimestamp) -> Bool {
         return lhs.secondsComponent == rhs.secondsComponent &&
                lhs.nanosecondsComponent == rhs.nanosecondsComponent
     }

     public func advanced(by duration: Duration) -> MessagePackTimestamp {
         let (secondsToAdd, attosecondsToAdd) = duration.components
         precondition(attosecondsToAdd >= 0)

         var secondsComponent = secondsComponent + secondsToAdd

         var (nanosecondsToAdd, remainder) = attosecondsToAdd.quotientAndRemainder(dividingBy: 1_000_000_000)
         if remainder >= 500_000_000 {
             nanosecondsToAdd += 1
         }

         var nanosecondsComponent = Int64(self.nanosecondsComponent) + nanosecondsToAdd
         if nanosecondsComponent >= Int64(Self.nanosecondsComponentMax) {
             secondsComponent += 1
             nanosecondsComponent -= 1_000_000_000
         }

         return MessagePackTimestamp(secondsComponent: secondsComponent,
                                     nanosecondsComponent: UInt32(nanosecondsComponent))
     }

     public func duration(to other: MessagePackTimestamp) -> Duration {
         let secondsToOther = other.secondsComponent - self.secondsComponent
         let nanosecondsToOther = Int64(other.nanosecondsComponent) - Int64(self.nanosecondsComponent)

         return .seconds(secondsToOther) + .nanoseconds(nanosecondsToOther)
     }
 }

 // 定义 `Duration` 及其 `components` 属性
 public struct Duration: Equatable {
     private let totalNanoseconds: Int64

     public init(secondsComponent: Int64, attosecondsComponent: Int64) {
         self.totalNanoseconds = secondsComponent * 1_000_000_000 + attosecondsComponent
     }

     public var components: (seconds: Int64, attoseconds: Int64) {
         let seconds = totalNanoseconds / 1_000_000_000
         let attoseconds = totalNanoseconds % 1_000_000_000
         return (seconds, attoseconds)
     }

     public static func seconds(_ seconds: Int64) -> Duration {
         return Duration(secondsComponent: seconds, attosecondsComponent: 0)
     }

     public static func nanoseconds(_ nanoseconds: Int64) -> Duration {
         return Duration(secondsComponent: 0, attosecondsComponent: nanoseconds)
     }

     public static func +(lhs: Duration, rhs: Duration) -> Duration {
         return Duration(secondsComponent: 0, attosecondsComponent: lhs.totalNanoseconds + rhs.totalNanoseconds)
     }

     public static func ==(lhs: Duration, rhs: Duration) -> Bool {
         return lhs.totalNanoseconds == rhs.totalNanoseconds
     }
 }

 // 定义 `InstantProtocol`
 public protocol InstantProtocol: Comparable {
     func advanced(by duration: Duration) -> Self
     func duration(to other: Self) -> Duration
 }

 
 */
