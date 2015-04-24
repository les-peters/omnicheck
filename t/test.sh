rm /opt/omnicheck/*out /opt/omnicheck/*err
#rm ./*out ./*err
chmod 444 ./*out ./*err
prove $*
