const DominionDAO = artifacts.require('DominionDAO');

module.exports = async function(delpoyer){
    await delpoyer.deploy(DominionDAO)
}