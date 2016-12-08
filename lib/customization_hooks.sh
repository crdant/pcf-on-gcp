# If your personal install needs to hook into the install, I've offered some opportunities to do that.  You should redefine these
# functions in personal.sh

# The first hook I've needed was to update my root DNS to delegate the subdomain for this platform install to
# Google DNS. If your root DNS is at Google you won't need this. Otherwise you probably will.
update_root_dns () {
  true
}

overrides () {
  true
}
