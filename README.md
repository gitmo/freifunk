## freifunk ##
OLSR configs for the Airties WAV-281 and Freifunk Berlin.

### The Luci way ###

0. Flash image containing luci and all of freifunk, olsr, meshwizard
1. [Set password](http://192.168.1.1/cgi-bin/luci/admin/system/admin)
2. [Freifunk](http://192.168.1.200/cgi-bin/luci/admin/freifunk/)
	* Basic Setting:
	  - Community: Freifunk-Berlin
	  - Hostname, Location, Lat, Long
	* Contact
	  - Fill in your details
	* Mesh wizard
	  - enable for radio0
	  - channel: 10 (depends on your targeted [neighbour](http://openwifimap.net))
	  - registered IP: 104.xxx.xx.xx [(get one here)](http://ip.berlin.freifunk.net)
	  - leave rest at defaults for now	  
3. [Network / Wifi / radio0](http://192.168.1.1/cgi-bin/luci/admin/network/wireless/radio0.network1)

   Change BSSID to 02:CA:FF:EE:BA:BE (depends on your targeted neighbour)

4. ???
5. Profit!
   * [Test network](http://192.168.1.1/cgi-bin/luci/admin/network/diagnostics/)
   * [Check firewall](http://192.168.1.1/cgi-bin/luci/admin/network/firewall/rules/)

### Let me just hack some text files ###

Please use this [diff](https://github.com/gitmo/freifunk/commit/a4a52cb263792928a64b30768c54602e60c07e36) as a guideline.

You'll have to edit at least

* /etc/config/network
* /etc/config/wireless
* /etc/config/olsrd
* /etc/config/freifunk

