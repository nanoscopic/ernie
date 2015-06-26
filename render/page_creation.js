function make_page( box ) {
    var cascade = new DomCascade();
    box.style.position = 'relative';
    var res = cascade.append( box, [
      {
        name: 'table',
        style: {
          position: 'absolute',
          top: '0px',
          height: '40px',
          /*background: 'blue',*/
          marginBottom: '0px',
          width: '100%'
        },
        sub: [
          {
            name: 'tr',
            sub: [
              {
                name: 'td',
                style: { width: '40%' },
                sub: {
                  name: 'img',
                  src: 'logo4.png',
                  attr: {
                    width: '350px'
                  }
                }
              },
              {
                name: 'td',
                attr: { align: 'right' },
                sub: {
                  name: 'table',
                  style: {
                    marginBottom: '0px',
                  },
                  sub: [
                    {
                      name: 'tr',
                      sub: [
                        { name: 'td', sub: { name: 'text', text: 'Report:' } },
                        { name: 'td', style: { minWidth: '60px' }, sub: { name: 'text', text: '6' } },
                        { name: 'td', sub: { name: 'text', text: 'Survey:' } },
                        { name: 'td', sub: { name: 'text', text: 'Multiple Surveys' } }
                      ]
                    },
                    {
                      name: 'tr',
                      sub: [
                        { name: 'td', sub: { name: 'text', text: 'Submitted by:' } },
                        { name: 'td', sub: { name: 'text', text: '' } },
                        { name: 'td', sub: { name: 'text', text: 'Submitted on:' } },
                        { name: 'td', sub: { name: 'text', text: 'Jan 15, 2014' } },
                      ]
                    },
                    {
                      name: 'tr',
                      sub: [
                        { name: 'td', sub: { name: 'text', text: 'A:' } },
                        { name: 'td', attr: { colspan: '3' }, sub: { name: 'text', text: 'B' } },
                      ]
                    },
                    {
                      name: 'tr',
                      sub: [
                        { name: 'td', sub: { name: 'text', text: 'C:' } },
                        { name: 'td', attr: { colspan: '3' }, sub: { name: 'text', text: 'D' } },
                      ]
                    },
                  ]
                }
              }
            ]
          },
        ]
      },
      {
        name: 'div',
        class: 'inside',
        ref: 'inside',
        style: {
          position: 'absolute',
          top: '110px',
          bottom: '10px'
        }
      }
    ] );
    return res.refs.inside;
  }