# Server Clock

**Server Clock** is a PowerShell script designed to display the system clock of a chosen web server (Default: https://time.is).  

## Disclaimer

While **Server Clock** aims to be accurate, no warranty is given. Use at your own risk!

## How it works

1. **Server Clock** sends a HTTP HEAD request to a chosen web server using cURL.
2. The web server processes the request and sends back a HTTP response along with a generated `date` header.
3. **Server Clock** guesses how much time it has passed since the generation of the `date` header. The guess is based on cURL `time_pretransfer`, `time_starttransfer`, and `time_total`.
4. When cURL operation ends, a stopwatch will start ticking.
5. The displayed clock will be the result of the following:
    - HTTP `date` + Guessed Time-To-Respond + Stopwatch

## Attempts to Improve Accuracy
### Sync
<img src="./assets/timeline.png" width="900" alt="Creating a shortcut file"/>

Since `date` format looks like `Sat, 1 Jan 2000 12:00:00 GMT`, time units below 1 second are omitted. *Although not garunteed*, it will be assumed that the omitted time units are truncated, not rounded. The trailing 0.999s will mean 0s instead of 1s in this case. As shown in the above image, the `date` generation time is always between the values of `date` and `date`+1s (red bars).  
  
During the sync process, **Server Clock** creates an estimation as shown as a green bar in the above image. Because `date` has a truncated value, any accurate estimation must be greater than or equal to the `date` value with the difference being less than 1 second. Additionally, all estimations must be less than or equal to the time when `date` is generated. The sync process will repeat 20-30 times with the delay of 250ms by default.  
  
In an imaginary world, the sync process will look like the following:  
(only seconds and below are shown)  

|Accurate `date` Generation Time|   `date`  |**Server Clock**|Off By   |
|:-----------------------------:|:---------:|:--------------:|:-------:|
| 0.6785                        | 0         | 0              | -0.6785 |
| 0.9285                        | 0         | 0.25           | -0.6785 |
| 1.1785                        | 1         | 1              | +0.1785 |
| 1.4285                        | 1         | 1.25           | +0.1785 |
| 1.6785                        | 1         | 1.5            | +0.1785 |
| 1.9285                        | 1         | 1.75           | +0.1785 |
| 2.1785                        | 2         | 2              | +0.1785 |
  
and so on.  

### Clock Pooling

<img src="./assets/clock_pooling.png" width="900" alt="Creating a shortcut file"/>

The second version of **Server Clock** follows the same idea with a different approach called Clock Pooling. Aiming to take care of the outliers, the process generates a pool of clocks and selects a clock with the largest estimation within one-second timeframe with the most number of clocks.  


## Resources and References
- [How to run cURL command via PowerShell](https://www.delftstack.com/howto/powershell/run-curl-command-via-powershell/) - Use curl.exe instead of curl in PowerShell
- [Everything cURL](https://everything.curl.dev/) - cURL commands and variables
- [A Question of Timing](https://blog.cloudflare.com/a-question-of-timing/) - cURL Timings Visual
- [HTTP request methods: HEAD](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/HEAD) - Request only for header 
- [Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content](https://httpwg.org/specs/rfc7231.html#header.date) - `date` header in HTTP response
- [Time.is : exact time for any time zone](https://time.is/) - Tested against this webserver

